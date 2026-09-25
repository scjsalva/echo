class Dashboard
  WAITING_LIMIT = 10
  REVIEW_QUEUE_LIMIT = 15

  # What the dashboard looks like before GitHub or Jira are connected.
  EMPTY = {
    connected: {}, me: {}, tokens_today: nil, team: [], repos: [],
    agents: [], pull_requests: [], github_notifications: [], jira_tickets: [], jira_notifications: []
  }.freeze

  # Everything Echo can read right now. Claude Code is always there (Echo won't
  # boot without it); GitHub and Jira aren't wired up yet.
  def self.current
    jira = Jira::Connection.status
    github = Github::Connection.status

    new(data: {
      connected: { jira: jira[:connected], github: github[:connected] },
      me: { github_login: github[:login] },
      repos: Github::Preferences.repos, team: Github::Preferences.team,
      pull_requests: github[:connected] ? Github::DashboardData.pull_requests : [],
      github_notifications: github[:connected] ? Github::DashboardData.notifications : [],
      agents: ClaudeCode::Session.live.map(&:to_agent) + ClaudeCode::Job.recent,
      tokens_today: ClaudeCode::Usage.tokens_today,
      jira_tickets: jira[:connected] ? Jira::DashboardData.tickets(site: jira[:site]) : [],
      jira_notifications: jira[:connected] ? Jira::DashboardData.notifications(site: jira[:site]) : []
    })
  end

  def initialize(data: EMPTY, dismissed_keys: Dismissal.pluck(:item_key))
    @data = EMPTY.with_indifferent_access.merge(data)
    @dismissed_keys = dismissed_keys.to_set
  end

  def shell_props
    {
      waiting_count: waiting_items.count { it[:status] == "open" },
      unread_count: (github_notifications + jira_notifications).count { it[:unread] },
      missing_connections: connections.reject { it[:connected] || it[:optional] }.map { it[:name] },
      live: ClaudeCode::Hooks.installed?,
      updated_at: Time.current
    }
  end

  def overview_props
    open_items = waiting_items.select { it[:status] == "open" }

    {
      shell: shell_props,
      stats: stats,
      waiting: { items: open_items.first(WAITING_LIMIT), total: open_items.size },
      review_queue: { items: review_queue.first(REVIEW_QUEUE_LIMIT), total: review_queue.size },
      agents: agents,
      pull_requests: pull_requests,
      github_notifications: github_notifications,
      jira_tickets: jira_tickets,
      jira_notifications: jira_notifications,
      connections: connections
    }
  end

  def agents_props
    { shell: shell_props, agents: }
  end

  def inbox_props
    { shell: shell_props, connections:, waiting: { items: waiting_items, total: waiting_items.count { it[:status] == "open" } },
      agents:, pull_requests:, github_notifications:, jira_tickets:, jira_notifications: }
  end

  def github_props
    { shell: shell_props, connected: @data.dig(:connected, :github) || false, synced_at: Github::Sync.synced_at,
      agents: [], pull_requests:, review_queue:, github_notifications:, jira_tickets:, jira_notifications:,
      team: @data[:team], repos: @data[:repos] }
  end

  def jira_props
    { shell: shell_props, connected: @data.dig(:connected, :jira) || false, synced_at: Jira::Sync.synced_at,
      agents: [], jira_tickets:, jira_notifications: }
  end

  def settings_props
    repos = Github::Preferences.repos
    { shell: shell_props, connections:, time_zone: LocalTimeZone.props, notifications: Notifier.preferences, github: Github::Preferences.props,
      claude: { skills: Skills.props(repos), context: ClaudeCode::Context.settings_props(repos) } }
  end

  def connections
    connected = @data[:connected]

    [
      { key: "github", name: "GitHub", connected: connected[:github] || false, setup: true, logout: false,
        detail: connected[:github] ? Github::Connection.status[:detail] : "Reads your PRs, review requests and notifications through the GitHub CLI (gh)." },
      { key: "jira", name: "Jira", connected: connected[:jira] || false, setup: true,
        detail: connected[:jira] ? Jira::Connection.status[:detail] : "Reads your tickets and mentions through the Atlassian CLI (acli)." },
      { key: "claude_hooks", name: "Claude Code hooks", connected: ClaudeCode::Hooks.installed?, optional: true, setup: true, instant: true,
        detail: ClaudeCode::Hooks.installed_url&.then { "Sending session events to #{it}" } ||
          "Optional. Shows when an agent is waiting on you, the moment it happens, and refreshes open pages right away." }
    ]
  end

  def agents
    @agents ||= @data[:agents].map do |agent|
      agent.merge(loops: Array(agent[:loops]), subagents: Array(agent[:subagents]), jobs: Array(agent[:jobs]))
    end
  end

  def pull_requests
    @pull_requests ||= @data[:pull_requests].map do |pr|
      full_name = pr[:full_name] || "#{@data[:github_org]}/#{pr[:repo]}"
      pr.reverse_merge(
        key: "#{full_name}##{pr[:number]}", full_name:,
        url: "https://github.com/#{full_name}/pull/#{pr[:number]}", mine: pr[:author] == me
      ).merge(draft: pr[:draft] || false, requested_from_me: pr[:requested_from_me] || false, reviews: Array(pr[:reviews]))
    end
  end

  def review_queue
    @review_queue ||= pull_requests
      .select { !it[:mine] && !it[:draft] && @data[:repos].include?(it[:full_name]) }
      .sort_by { Time.zone.parse(it[:opened].to_s).to_i }.reverse
  end

  def github_notifications
    @github_notifications ||= @data[:github_notifications].map do |notification|
      notification.reverse_merge(pr_key: "#{@data[:github_org]}/#{notification[:repo]}##{notification[:number]}")
        .merge(unread: (notification[:unread] && !muted?("github", notification[:reason])) || false)
    end
  end

  def jira_tickets
    @jira_tickets ||= @data[:jira_tickets].map do |ticket|
      ticket.reverse_merge(url: "https://#{@data[:jira_site]}/browse/#{ticket[:key]}", assigned_to_me: ticket[:assignee] == @data.dig(:me, :jira_name))
    end
  end

  def jira_notifications
    @jira_notifications ||= @data[:jira_notifications].map { it.merge(unread: (it[:unread] && !muted?("jira", it[:kind])) || false) }
  end

  # Kinds you unticked under Custom still show in the inbox, but as read: they
  # don't notify you, so they shouldn't wait for you to open them either.
  def muted?(source, kind)
    @muted ||= Notifier.scope == "custom" ? (Notifier::TYPES.pluck(:id) - Notifier.enabled_types).to_set : Set.new
    @muted.include?(Notifier.type_of(source, kind))
  end

  # The review queue minus what's already approved, for the review reminder.
  def unapproved_reviews = review_queue.reject { it[:review_state] == "approved" }

  def waiting_items
    @waiting_items ||= WaitingItems.new(
      agents:, pull_requests:, github_notifications:, jira_tickets:, jira_notifications:, dismissed_keys: @dismissed_keys
    ).all
  end

  private

  def me = @data.dig(:me, :github_login)

  def stats
    my_tickets = jira_tickets.select { it[:assigned_to_me] }

    {
      agents: {
        agents: agents.size,
        busy: agents.count { it[:status] == "busy" },
        tokens_used: @data[:tokens_today] || agents.sum { it[:tokens_today] }
      },
      github: {
        team: review_queue.count { @data[:team].include?(it[:author]) },
        mine: pull_requests.count { it[:mine] },
        watching: pull_requests.count { |pr| !pr[:mine] && github_notifications.any? { it[:pr_key] == pr[:key] } }
      },
      jira: {
        open: my_tickets.count { it[:category] != "done" },
        done: my_tickets.count { it[:category] == "done" }
      }
    }
  end
end
