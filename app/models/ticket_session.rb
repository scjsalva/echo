require "shellwords"

# Opens Claude Code in a terminal tab to talk a Jira ticket through before you
# pick it up. A ticket can span repos, or turn out to belong to a package, so it
# starts in the folder holding your local repos and works out which with you.
# It only reads until you ask it to build anything. Each one is recorded with the
# session id Echo gave it, so it can be brought back later.
class TicketSession < ApplicationRecord
  class Error < StandardError; end

  cattr_accessor :briefs, default: Rails.root.join("tmp/ticket-briefs")

  # Echo's own rules for the session, whichever skill guides it: the skill can't loosen these.
  RULES = <<~RULES.freeze
    - Work out with the user which repo (or repos) the change belongs in. Don't assume it's the one the ticket
      came from: it may span two, or be a bug in a package. Agree on it before anything is built.
    - Stay read-only until the user asks you to build it: don't edit files, switch branches, or write to Jira
      (no assigning, commenting or moving the ticket), or anywhere else.
    - When they want to go ahead, they'll ask you to make the change or invoke a skill for it. Follow that.
  RULES
  RELATED_LIMIT = 8
  RELATED_TEXT = 1_500
  URL = %r{https?://[^[:space:]<>()\[\]"'`]+}
  LINK_KINDS = [
    [ "GitHub", /github\.com/ ], [ "Recordings and bug captures", /jam\.dev|loom\.com|vimeo\.com|youtube\.com|youtu\.be/ ],
    [ "Designs, docs and wiki pages", %r{figma\.com|/wiki/|confluence|notion\.so|docs\.google\.com} ], [ "Tickets", %r{/browse/[A-Z][A-Z0-9_]+-\d+} ]
  ].freeze

  def self.options(key)
    last = latest(key)
    { repos: repos.map { |repo, path| { repo:, path: ClaudeCode.abbreviate(path) } },
      last_session: last && { opened_at: last.created_at, live: last.live?, resumable: last.live? || last.transcript? } }
  end

  def self.latest(key) = where(ticket_key: key).order(:created_at).last

  # Its tab comes forward if it's still running; otherwise it picks up again in a new tab.
  def self.resume(key)
    session = latest(key) or raise Error, "Echo hasn't opened a session for #{key}"
    return ClaudeCode::Focus.focus(session.session_id) if session.live?
    raise Error, "That session's transcript is gone, so it can't be resumed. Ask Claude again." unless session.transcript?

    TerminalApp.run_in_tab(ClaudeCode::Resume.command(session.session_id, session.path))
  end

  def self.start(key)
    raise Error, "Set your local repos in Settings → GitHub first" if repos.empty?

    folder = home_folder
    detail = Jira::TicketDetail.fetch(key, site: Jira::Connection.status[:site])
    brief = briefs.tap(&:mkpath).join("#{key}.md")
    brief.write(brief_for(detail))
    session = create!(ticket_key: key, session_id: SecureRandom.uuid, path: folder.to_s)
    TerminalApp.run_in_tab(command(folder, detail, brief, session.session_id))
  end

  def live? = ClaudeCode::Session.find(session_id).present?
  def transcript? = ClaudeCode.transcript_path(session_id).present?

  # Everything Echo can gather on its own, then the skill's instructions for digging further, then Echo's rules.
  def self.brief_for(detail)
    related = related_tickets(detail)
    sections = [
      "# #{detail[:key]}: #{detail[:title]}",
      [ detail[:type], detail[:status], detail[:url] ].compact.join(" · "),
      section("Description", detail[:description] || "No description."),
      *detail[:more_details].map { section("More details", it) },
      section("Environment", detail[:environment]),
      section("Comments, newest first", detail[:comments].map { "**#{it[:author]}**, #{it[:created].to_s[0, 10]}:\n#{it[:text]}" }.join("\n\n").presence),
      section("Related tickets", related.presence),
      section("Links in the ticket", links(detail, related)),
      section("Attachments", attachments(detail)),
      section("Pull requests that mention #{detail[:key]}", pull_requests(detail[:key])),
      section("Local repos (main checkouts)", repos.map { |repo, path| "- #{repo}: #{path}" }.join("\n")),
      "## How to help\n\n#{Skills.for("ticket_session").instructions.gsub(/^(#+) /, '#\\1 ')}",
      "## Echo's rules\n\n#{RULES}"
    ]
    sections.compact.join("\n\n")
  end

  # The parent, subtasks and linked tickets, each read in full (a few at once), not just their titles.
  def self.related_tickets(detail)
    related = (detail[:parent] ? [ detail[:parent].merge(relation: "parent") ] : []) + detail[:subtasks].map { it.merge(relation: "subtask") } + detail[:links]
    site = Jira::Connection.status[:site]
    related.first(RELATED_LIMIT).map { |t| Thread.new { [ t, read_ticket(t[:key], site) ] } }.map(&:value).map do |t, full|
      said = full && [ full[:description], *full[:comments].first(2).map { "#{it[:author]}: #{it[:text]}" } ].compact.join("\n\n").truncate(RELATED_TEXT)
      "### #{t[:key]}: #{t[:title]}\n#{t[:relation]} · #{t[:status]}#{"\n\n#{said}" if said.present?}"
    end.join("\n\n")
  end

  # A related ticket in full, or nothing when it can't be read (e.g. no access to its project).
  def self.read_ticket(key, site)
    Jira::TicketDetail.fetch(key, site:)
  rescue Jira::Cli::Error, ArgumentError
    nil
  end

  # Every link in the ticket, its comments and its related tickets, grouped by what opens it.
  def self.links(detail, related)
    text = [ detail[:description], detail[:environment], *detail[:more_details], *detail[:comments].map { it[:text] }, related ].compact.join("\n")
    urls = text.scan(URL).map { it.sub(/[.,;:!?]+\z/, "") }.uniq.reject { it.start_with?(detail[:url].to_s) }
    return if urls.empty?

    groups = urls.group_by { |url| LINK_KINDS.find { |_, pattern| url.match?(pattern) }&.first || "Other" }
    (LINK_KINDS.map(&:first) + [ "Other" ]).filter_map { |kind| groups[kind] && "#{kind}:\n#{groups[kind].map { "- #{it}" }.join("\n")}" }.join("\n\n")
  end

  def self.attachments(detail)
    return if detail[:attachments].empty?

    files = detail[:attachments].map { "- #{it[:name]} (#{[ it[:type], ActiveSupport::NumberHelper.number_to_human_size(it[:size]) ].compact.join(', ')})" }
    "#{files.join("\n")}\n\nEcho can only list these, not open them."
  end

  # PRs in your repos (the ones you watch, and your local clones) that mention the ticket's key,
  # e.g. earlier fixes or work in progress.
  def self.pull_requests(key)
    scope = (Github::Preferences.repos + repos.keys).uniq.map { "repo:#{it}" }
    return if scope.empty?

    query = ERB::Util.url_encode([ %("#{key}"), "type:pr", *scope ].join(" "))
    found = Github::Cli.run("api", "search/issues?q=#{query}&per_page=10", json: true)["items"].to_a
    found.map { "- #{it['title']} (#{it['pull_request']&.dig('merged_at') ? 'merged' : it['state']}) #{it['html_url']}" }.join("\n").presence
  rescue Github::Cli::Error
    nil
  end

  def self.command(path, detail, brief, session_id)
    name = "#{detail[:key]}: #{detail[:title]}".truncate(60)
    prompt = "Read the ticket brief at #{brief} and follow its How to help section."
    "cd #{Shellwords.escape(path.to_s)} && claude --session-id #{session_id} -n #{Shellwords.escape(name)} #{Shellwords.escape(prompt)}"
  end

  def self.section(title, body) = body.presence && "## #{title}\n\n#{body}"

  def self.repos = Github::LocalRepos.all

  # The deepest folder holding every local repo, e.g. ~/Projects, so any of them can be read from there.
  def self.home_folder
    parts = repos.values.map { Pathname(it).expand_path.each_filename.to_a }
    common = parts.reduce { |a, b| a.take_while.with_index { |part, i| part == b[i] } }
    common = parts.first[0...-1] if parts.one?
    Pathname("/").join(*common)
  end

  private_class_method :brief_for, :related_tickets, :read_ticket, :links, :attachments, :pull_requests, :command, :section, :repos, :home_folder
end
