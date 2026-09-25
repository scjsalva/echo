# Sends a desktop notification the first time something new needs you: a blocked
# agent or a Jira mention or assignment, or (with "Custom") whichever kinds of
# notification you pick. Each item is only ever sent once.
module Notifier
  SCOPES = %w[waiting custom].freeze
  DEFAULTS = { "notify_desktop" => "on", "notify_scope" => "waiting" }.freeze

  # Every kind of notification Echo sends. The waiting ones are what "Waiting on you" covers.
  TYPES = [
    { id: "agent.blocked", group: "Agents", label: "An agent is waiting on you", waiting: true },
    { id: "system.review_reminder", group: "System", label: "Review reminder" },
    { id: "github.ready_for_review", group: "System", label: "A teammate's PR is ready for review" },
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
  GITHUB_TYPES = { "team_mention" => "mention", "review_dismissed" => "reviewed", "changes_requested_other" => "reviewed", "ci_activity" => "ci",
    "author" => "other", "assign" => "other", "state_change" => "other", "subscribed" => "other", "manual" => "other" }.freeze
  BURST = 3
  # How often the review reminder says how many PRs are waiting for review, in minutes; 0 is off.
  REMINDER_OPTIONS = [ 0, 15, 30, 60, 120, 240 ].freeze
  REMINDER_DEFAULT = 30
  SEEDED = "notifier_seeded".freeze

  def self.preferences
    {
      desktop: setting("notify_desktop") == "on", scope:, types: TYPES, enabled_types:,
      reminder_minutes:, reminder_options: REMINDER_OPTIONS,
      sound: Setting["notify_sound"] || DesktopNotification.default_sound,
      sounds: DesktopNotification.sounds, available: DesktopNotification.available?, settings_hint: DesktopNotification.settings_hint
    }
  end

  # "everything" is what Custom was called before it could be narrowed down.
  def self.scope = setting("notify_scope") == "everything" ? "custom" : setting("notify_scope")

  # What Custom sends: everything but what you untick, so kinds added later start on.
  def self.enabled_types = TYPES.pluck(:id) - JSON.parse(Setting["notify_types_off"] || "[]")

  def self.reminder_minutes = (Setting["review_reminder_minutes"] || REMINDER_DEFAULT).to_i

  def self.update(desktop: nil, scope: nil, sound: nil, types: nil, reminder_minutes: nil)
    raise ArgumentError, "Unknown reminder interval" if reminder_minutes && !REMINDER_OPTIONS.include?(reminder_minutes.to_i)
    raise ArgumentError, "Unknown scope" if scope && !SCOPES.include?(scope)
    raise ArgumentError, "Unknown notification type" if types && (types - TYPES.pluck(:id)).any?
    raise ArgumentError, "Unknown sound" if sound && sound != "none" && !DesktopNotification.sounds.include?(sound)

    Setting["notify_desktop"] = desktop ? "on" : "off" unless desktop.nil?
    Setting["notify_scope"] = scope if scope
    Setting["notify_sound"] = sound if sound
    Setting["notify_types_off"] = (TYPES.pluck(:id) - types).to_json if types
    Setting["review_reminder_minutes"] = reminder_minutes.to_i.to_s if reminder_minutes
  end

  def self.type_of(source, kind)
    case source
    when "agent" then "agent.blocked"
    # A reason GitHub adds later counts as other activity rather than matching no checkbox.
    when "github" then "github.#{GITHUB_TYPES.fetch(kind, kind)}".then { |id| TYPES.any? { it[:id] == id } ? id : "github.other" }
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
      DesktopNotification.show(**two_lines(title: "#{fresh.size - BURST} more", message: "Open Echo to see them all."), sound: nil)
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

  def self.test = DesktopNotification.show(**two_lines(title: "Test notification", message: "This is how Echo will get your attention."),
    sound: preferences[:sound])

  def self.candidates(dashboard)
    custom = scope == "custom"
    wanted = custom ? enabled_types.to_set : TYPES.select { it[:waiting] }.pluck(:id).to_set
    waiting = dashboard.waiting_items.select { it[:status] == "open" && wanted.include?(type_of(it[:source], it[:kind])) }.map do |item|
      { key: item[:delivery_key],
        notification: two_lines(title: "Waiting on you", subtitle: item[:label], message: [ item[:title], item[:actor] ].compact.join(" · "),
          url: link(item[:ref])) }
    end
    waiting += review_reminder(dashboard)
    return waiting unless custom

    waiting_keys = dashboard.waiting_items.map { it[:delivery_key] }.to_set
    github = dashboard.github_notifications.select do
      it[:unread] && !waiting_keys.include?("github-#{it[:id]}") && wanted.include?(type_of("github", it[:reason]))
    end.map do |n|
      { key: "github-notification-#{n[:id]}-#{n[:at].to_i}",
        notification: two_lines(title: n[:title] || n[:pr_key], subtitle: "GitHub · #{n[:pr_key].split('/').last}",
          message: Github::NotificationText.for(reason: n[:reason], actor: n[:actor], body: n[:body], mine: n[:mine]),
          url: link(pr_key: n[:pr_key], notification_id: n[:id])) }
    end

    jira = dashboard.jira_notifications.select do
      it[:unread] && !waiting_keys.include?("jira-#{it[:id]}") && wanted.include?(type_of("jira", it[:kind]))
    end
    waiting + github + jira.map do |n|
      { key: "jira-notification-#{n[:id]}",
        notification: two_lines(title: "Jira · #{n[:key]}", message: Jira::NotificationText.for(kind: n[:kind], actor: n[:actor], body: n[:body]),
          url: link(ticket_key: n[:key], notification_id: n[:id])) }
    end
  end

  # One reminder per interval, e.g. every 30 minutes, while PRs are waiting for review.
  # Its key names the interval it's for, so each one is sent once.
  def self.review_reminder(dashboard)
    minutes = reminder_minutes
    return [] if minutes.zero? || (scope == "custom" && !enabled_types.include?("system.review_reminder"))

    count = dashboard.unapproved_reviews.size
    return [] if count.zero?

    [ { key: "github-review-reminder-#{minutes}-#{Time.current.to_i / (minutes * 60)}",
      notification: two_lines(title: "Review queue", subtitle: "GitHub",
        message: "#{count} PR#{'s' unless count == 1} waiting for review", url: "#{DesktopNotification.base_url}/github") } ]
  end

  # Every notification, OS or in-app, reads as two lines: the title, then the
  # message led by what would have been a third line (e.g. "GitHub · web").
  def self.two_lines(title:, message:, subtitle: nil, url: nil)
    { title:, subtitle: "", message: [ subtitle.presence, message.to_s.squish.presence ].compact.join(" · "), url: }.compact
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

  private_class_method :candidates, :review_reminder, :two_lines, :link, :setting
end
