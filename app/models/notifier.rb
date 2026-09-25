# Sends a desktop notification the first time something new needs you: a blocked
# agent or a Jira mention or assignment, or (with "Custom") whichever kinds of
# notification you pick. Each item is only ever sent once.
module Notifier
  SCOPES = %w[waiting custom].freeze
  DEFAULTS = { "notify_desktop" => "on", "notify_scope" => "waiting" }.freeze

  # Every kind of notification Echo sends. The waiting ones are what "Waiting on you" covers.
  TYPES = [
    { id: "agent.blocked", group: "Agents", label: "An agent is waiting on you", waiting: true },
    { id: "github.review_requested", group: "GitHub", label: "Review requested from you", waiting: true },
    { id: "github.mention", group: "GitHub", label: "You or your team are mentioned", waiting: true },
    { id: "github.changes_requested", group: "GitHub", label: "Changes requested on your PR", waiting: true },
    { id: "github.follow_up", group: "GitHub", label: "New commits after your review" },
    { id: "github.approved", group: "GitHub", label: "Someone approves a PR" },
    { id: "github.reviewed", group: "GitHub", label: "Someone reviews a PR, or a review is dismissed" },
    { id: "github.comment", group: "GitHub", label: "Comments" },
    { id: "github.merged", group: "GitHub", label: "A PR is merged" },
    { id: "github.closed", group: "GitHub", label: "A PR is closed" },
    { id: "github.ci", group: "GitHub", label: "CI activity" },
    { id: "github.other", group: "GitHub", label: "Other activity on PRs you watch" },
    { id: "jira.mention", group: "Jira", label: "You're mentioned", waiting: true },
    { id: "jira.assigned", group: "Jira", label: "A ticket is assigned to you", waiting: true },
    { id: "jira.comment", group: "Jira", label: "Comments" },
    { id: "jira.transition", group: "Jira", label: "Status changes" }
  ].freeze
  GITHUB_TYPES = { "team_mention" => "mention", "review_dismissed" => "reviewed", "ci_activity" => "ci",
    "author" => "other", "assign" => "other", "state_change" => "other", "subscribed" => "other", "manual" => "other" }.freeze
  BURST = 3
  SEEDED = "notifier_seeded".freeze

  def self.preferences
    {
      desktop: setting("notify_desktop") == "on", scope:, types: TYPES, enabled_types:,
      sound: Setting["notify_sound"] || DesktopNotification.default_sound,
      sounds: DesktopNotification.sounds, available: DesktopNotification.available?, settings_hint: DesktopNotification.settings_hint
    }
  end

  # "everything" is what Custom was called before it could be narrowed down.
  def self.scope = setting("notify_scope") == "everything" ? "custom" : setting("notify_scope")

  # What Custom sends: everything until you untick something.
  def self.enabled_types = Setting["notify_types"] ? JSON.parse(Setting["notify_types"]) : TYPES.pluck(:id)

  def self.update(desktop: nil, scope: nil, sound: nil, types: nil)
    raise ArgumentError, "Unknown scope" if scope && !SCOPES.include?(scope)
    raise ArgumentError, "Unknown notification type" if types && (types - TYPES.pluck(:id)).any?
    raise ArgumentError, "Unknown sound" if sound && sound != "none" && !DesktopNotification.sounds.include?(sound)

    Setting["notify_desktop"] = desktop ? "on" : "off" unless desktop.nil?
    Setting["notify_scope"] = scope if scope
    Setting["notify_sound"] = sound if sound
    Setting["notify_types"] = types.uniq.to_json if types
  end

  def self.type_of(source, kind)
    case source
    when "agent" then "agent.blocked"
    when "github" then "github.#{GITHUB_TYPES.fetch(kind, kind)}"
    else "#{source}.#{kind}"
    end
  end

  def self.deliver_new(dashboard = Dashboard.current)
    candidates = candidates(dashboard)
    sent = Delivery.where(item_key: candidates.map { it[:key] }).pluck(:item_key).to_set
    fresh = candidates.reject { sent.include?(it[:key]) }
    # The first run only records what's already there, so turning Echo on doesn't send a flood.
    seeding = Setting[SEEDED].nil?
    Setting[SEEDED] = "1" if seeding
    return if fresh.empty?

    Delivery.insert_all(fresh.map { { item_key: it[:key], created_at: Time.current, updated_at: Time.current } })
    return if seeding || !preferences[:desktop]

    fresh.first(BURST).each { DesktopNotification.show(**it[:notification], sound: preferences[:sound]) }
    if fresh.size > BURST
      DesktopNotification.show(title: "Echo", message: "…and #{fresh.size - BURST} more. Open Echo to see them all.", sound: nil)
    end
  end

  # The same new-item feed, for in-app alerts on whatever page is open.
  def self.alerts(dashboard = Dashboard.current)
    candidates(dashboard).map { |c| { id: c[:key], source: c[:key].split("-").first, **c[:notification] } }
  end

  # In-app alerts only show when OS notifications won't, so you're not told twice.
  def self.in_app? = !(preferences[:desktop] && preferences[:available])

  def self.in_app_sound
    preferences[:sound] unless preferences[:sound] == "none"
  end

  def self.test = DesktopNotification.show(title: "Echo", subtitle: "Test notification", message: "This is how Echo will get your attention.",
    sound: preferences[:sound])

  def self.candidates(dashboard)
    custom = scope == "custom"
    wanted = custom ? enabled_types.to_set : TYPES.select { it[:waiting] }.pluck(:id).to_set
    waiting = dashboard.waiting_items.select { it[:status] == "open" && wanted.include?(type_of(it[:source], it[:kind])) }.map do |item|
      { key: item[:delivery_key],
        notification: { title: "Waiting on you", subtitle: item[:label], message: [ item[:title], item[:actor] ].compact.join(" · "),
          url: link(item[:ref]) } }
    end
    return waiting unless custom

    waiting_keys = dashboard.waiting_items.map { it[:delivery_key] }.to_set
    github = dashboard.github_notifications.select do
      it[:unread] && !waiting_keys.include?("github-#{it[:id]}") && wanted.include?(type_of("github", it[:reason]))
    end.map do |n|
      { key: "github-notification-#{n[:id]}-#{n[:at].to_i}",
        notification: { title: n[:title] || n[:pr_key], subtitle: "GitHub · #{n[:pr_key].split('/').last}",
          message: Github::NotificationText.for(reason: n[:reason], actor: n[:actor], body: n[:body]),
          url: link(pr_key: n[:pr_key], notification_id: n[:id]) } }
    end

    jira = dashboard.jira_notifications.select do
      it[:unread] && !waiting_keys.include?("jira-#{it[:id]}") && wanted.include?(type_of("jira", it[:kind]))
    end
    waiting + github + jira.map do |n|
      { key: "jira-notification-#{n[:id]}",
        notification: { title: "Jira · #{n[:key]}", subtitle: n[:kind].humanize, message: [ n[:actor], n[:body] ].compact.join(": "),
          url: link(ticket_key: n[:key], notification_id: n[:id]) } }
    end
  end

  # Clicking a notification opens the item itself: the agent, the ticket or the PR.
  def self.link(ref)
    base = DesktopNotification.base_url
    if ref[:agent_id] then "#{base}/agents?#{{ agent: ref[:agent_id] }.to_query}"
    elsif ref[:ticket_key] then "#{base}/jira?#{{ ticket: ref[:ticket_key], notification: ref[:notification_id] }.compact.to_query}"
    elsif ref[:pr_key] then "#{base}/github?#{{ pr: ref[:pr_key], notification: ref[:notification_id] }.compact.to_query}"
    else "#{base}/inbox"
    end
  end

  def self.setting(key) = Setting[key] || DEFAULTS.fetch(key)

  private_class_method :candidates, :link, :setting
end
