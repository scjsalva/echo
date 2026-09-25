# Pulls the tickets you're assigned to, watch or reported from Jira via acli and
# turns what changed into notifications. JiraSyncJob runs it every minute; the
# first sync only seeds recent comments, so connecting doesn't flood you with
# old news.
class Jira::Sync
  SCOPE = "(assignee = currentUser() OR watcher = currentUser() OR reporter = currentUser()) " \
          "AND (statusCategory != Done OR updated >= -14d)".freeze
  OVERLAP = 2.minutes
  SEED_WINDOW = 7.days
  THREADS = 6
  SYNCED_AT = "jira_synced_at".freeze
  ACCOUNT_ID = "jira_account_id".freeze

  def self.synced_at = Setting[SYNCED_AT]&.then { Time.zone.parse(it) }

  def run
    started_at = Time.current
    in_scope = search("#{SCOPE} ORDER BY updated DESC")
    return if in_scope.nil?

    first_sync = self.class.synced_at.nil?
    keys = in_scope.map { it["key"] }
    changed = first_sync ? keys : changed_keys(keys)

    fetch(changed).each { apply(it, first_sync:) }
    JiraTicket.where.not(key: keys).delete_all
    Setting[SYNCED_AT] = started_at.iso8601
  end

  private

  def me
    @me ||= Setting[ACCOUNT_ID] || detect_account_id
  end

  # Tickets updated since the last sync, plus any Echo hasn't seen yet.
  def changed_keys(keys)
    minutes = ((Time.current - self.class.synced_at + OVERLAP) / 60).ceil
    recent = Array(search("#{SCOPE} AND updated >= -#{minutes}m")).map { it["key"] }
    (recent + (keys - JiraTicket.where(key: keys).pluck(:key))).uniq
  end

  def search(jql)
    Jira::Cli.run("workitem", "search", "--jql", jql, "--paginate", "--fields", "key,status,assignee", json: true)
  end

  def fetch(keys)
    return [] if keys.empty?

    keys.each_slice((keys.size / THREADS.to_f).ceil).map do |slice|
      Thread.new { slice.filter_map { view(it) } }
    end.flat_map(&:value)
  end

  def view(key)
    Jira::Issue.new(Jira::Cli.run("workitem", "view", key, "--fields", Jira::Issue::FIELDS, json: true), me:)
  rescue Jira::Cli::Error => e
    Rails.logger.warn("Jira view #{key} failed: #{e.message}")
    nil
  end

  def apply(issue, first_sync:)
    ticket = JiraTicket.find_or_initialize_by(key: issue.key)
    was = ticket.slice(:status, :assigned_to_me, :comments_seen_at)
    ticket.assign_attributes(issue.attributes)

    unless first_sync || ticket.new_record?
      notify_transition(ticket, was[:status]) if ticket.status_changed?
      notify(ticket, "assigned", "assigned-#{ticket.key}-#{ticket.jira_updated_at.to_i}", at: ticket.jira_updated_at) if ticket.assigned_to_me && !was[:assigned_to_me]
    end
    notify_comments(ticket, issue.comments, since: was[:comments_seen_at] || (first_sync || ticket.new_record? ? SEED_WINDOW.ago : Time.zone.at(0)), seeding: first_sync)

    ticket.comments_seen_at = [ was[:comments_seen_at], *issue.comments.map(&:created) ].compact.max
    ticket.save!
    resolve_waiting(ticket, issue.comments)
  end

  def notify_transition(ticket, from)
    notify(ticket, "transition", "transition-#{ticket.key}-#{ticket.jira_updated_at.to_i}", body: "#{from} → #{ticket.status}", at: ticket.jira_updated_at)
  end

  def notify_comments(ticket, comments, since:, seeding:)
    comments.select { it.created > since && it.author_id != me && !it.bot }.each do |comment|
      notify(ticket, comment.mentions_me ? "mention" : "comment", "comment-#{comment.id}",
        actor: comment.author, body: comment.text.truncate(2_000), at: comment.created, read: seeding)
    end
  end

  def notify(ticket, kind, external_id, at:, actor: nil, body: nil, read: false)
    JiraNotification.create_with(kind:, ticket_key: ticket.key, actor:, body:, occurred_at: at, read_at: (Time.current if read))
      .find_or_create_by!(external_id:)
  end

  # A mention clears once you comment on the ticket after it; an assignment once
  # the ticket leaves To Do.
  def resolve_waiting(ticket, comments)
    last_reply = comments.select { it.author_id == me }.map(&:created).max
    open = JiraNotification.where(ticket_key: ticket.key, resolved_at: nil)
    open.where(kind: "mention").where(occurred_at: ...last_reply).update_all(resolved_at: Time.current, resolution: "You replied on Jira") if last_reply
    open.where(kind: "assigned").update_all(resolved_at: Time.current, resolution: "You moved it to #{ticket.status}") if ticket.status_category != "new"
  end

  def detect_account_id
    email = Jira::Connection.status[:email]
    mine = Array(search("assignee = currentUser() ORDER BY updated DESC")).first
    account_id = mine&.dig("fields", "assignee", "accountId")
    Setting[ACCOUNT_ID] = account_id if account_id && mine.dig("fields", "assignee", "emailAddress").in?([ email, nil ])
    account_id
  end
end
