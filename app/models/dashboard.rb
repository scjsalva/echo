class Dashboard
  WAITING_LIMIT = 10
  REVIEW_QUEUE_LIMIT = 15

  # What the dashboard looks like before GitHub or Jira are connected.
  EMPTY = {
    connected: {}, me: {}, tokens_today: nil, team: [], repos: [], jira_boards: { boards: [] },
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
      repos: Github::Preferences.repos, team: Github::Preferences.team_logins,
      pull_requests: github[:connected] ? Github::DashboardData.pull_requests : [],
      github_notifications: github[:connected] ? Github::DashboardData.notifications : [],
      agents: ClaudeCode::Session.live.map(&:to_agent) + ClaudeCode::Job.recent,
      tokens_today: ClaudeCode::Usage.tokens_today,
      jira_tickets: jira[:connected] ? with_board_tickets(Jira::DashboardData.tickets(site: jira[:site]), site: jira[:site]) : [],
      jira_boards: Jira::Boards.props,
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
      keep_awake: KeepAwake.current,
      lan_ip: LanAddress.ip,
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
      agents: [], jira_tickets:, jira_notifications:, jira_boards: @data[:jira_boards] }
  end

  # Your own tickets, in full, plus every ticket on the boards you added, each
  # saying which boards it's on and, from the board sync, its parent and whether it's a subtask.
  def self.with_board_tickets(mine, site:)
    on_boards = Jira::DashboardData.board_tickets(site:, me: Setting[Jira::Sync::ACCOUNT_ID]).index_by { it[:key] }
    mine.map { |t| on_boards[t[:key]] ? t.merge(on_boards.delete(t[:key]).slice(:boards, :parent, :subtask)) : t } + on_boards.values
  end

  def settings_props
    repos = Github::Preferences.repos
    { shell: shell_props, connections:, time_zone: LocalTimeZone.props, keep_awake: KeepAwake.props, notifications: Notifier.preferences, github: Github::Preferences.props,
      jira: @data[:jira_boards],
      claude: { skills: Skills.props(repos), context: ClaudeCode::Context.settings_props(repos),
        review_limit: Review.limit, review_limit_options: Review::LIMIT_OPTIONS } }
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
          "Optional. Shows when an agent is waiting on you, the moment it happens, and refreshes open pages right away." },
      { key: "claude_integration", name: "Echo in Claude Code", connected: ClaudeCode::Integration.installed?, optional: true, setup: true, instant: true,
        detail: ClaudeCode::Integration.installed? ? "Your counts are on Claude Code's status line, and /echo and /echo-review are ready in every session." :
          "Optional. Adds the /echo and /echo-review skills, and Echo's counts to Claude Code's status line. A status line you already have is kept." }
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

  # Your team's open PRs that are ready for review, in the repos you watch.
  def review_queue
    @review_queue ||= pull_requests
      .select { !it[:mine] && !it[:draft] && @data[:repos].include?(it[:full_name]) && @data[:team].include?(it[:author]) }
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

  # What nobody on your board has picked up (leaving out the Backlog and statuses
  # you hid; on a scrum board with a sprint running, only that sprint), and your
  # own tickets to do (your Backlog ones too) and done in the last 14 days.
  def jira_stats(my_tickets)
    boards = @data[:jira_boards][:boards].index_by { it[:id] }
    open = jira_tickets.select { |t| t[:boards].present? && t[:category] != "done" && t[:boards].keys.any? { shown_on?(boards[it.to_s.to_i], t) } }
    { unassigned: open.count { it[:assignee].blank? }, todo: my_tickets.count { it[:category] == "todo" }, done: my_tickets.count { it[:category] == "done" },
      boards: boards.any? }
  end

  def shown_on?(board, ticket)
    return false if board.blank? || ticket[:status].to_s.match?(/\Abacklog\z/i) || board[:statuses].any? { it[:name] == ticket[:status] && it[:hidden] }

    active = board[:sprints].to_a.select { it[:state] == "active" }.map { it[:name] }
    active.empty? || active.include?(ticket[:sprint])
  end

  def stats
    my_tickets = jira_tickets.select { it[:assigned_to_me] }

    {
      agents: {
        agents: agents.size,
        busy: agents.count { it[:status] == "busy" },
        tokens_used: @data[:tokens_today] || agents.sum { it[:tokens_today] }
      },
      github: {
        team: review_queue.size,
        mine: pull_requests.count { it[:mine] },
        watching: pull_requests.count { |pr| !pr[:mine] && github_notifications.any? { it[:pr_key] == pr[:key] } }
      },
      jira: jira_stats(my_tickets)
    }
  end
end
