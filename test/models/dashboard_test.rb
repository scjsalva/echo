require "test_helper"

class DashboardTest < ActiveSupport::TestCase
  setup { @dashboard = Dashboard.new(data: SampleData.load, dismissed_keys: []) }

  test "review queue is my team's ready PRs in watched repos, newest first" do
    queue = @dashboard.review_queue

    assert queue.any?
    assert queue.none? { it[:mine] || it[:draft] }
    assert queue.all? { SampleData.load[:team].include?(it[:author]) }
    assert queue.all? { %w[web editor assistant].include?(it[:repo]) }
    opened = queue.map { Time.zone.parse(it[:opened].to_s) }
    assert_equal opened.sort.reverse, opened

    synced = Dashboard.new(data: SampleData.load.merge(pull_requests: SampleData.load[:pull_requests].map { it.merge(opened: it[:opened].iso8601) }), dismissed_keys: [])
    assert_equal opened, synced.review_queue.map { Time.zone.parse(it[:opened]) }
  end

  test "Jira stats: unassigned on your board (not the Backlog or hidden statuses), and your own to do and done" do
    ticket = ->(key, status, category, board_ids, assignee: nil, mine: false) do
      { key:, title: key, type: "Story", status:, category:, priority: "P3", assignee:, assigned_to_me: mine, boards: board_ids.to_h { [ it, 0 ] } }
    end
    boards = { boards: [ { id: 1, statuses: [ { name: "Backlog", hidden: false }, { name: "Parked", hidden: true }, { name: "Doing", hidden: false } ] },
      { id: 2, statuses: [] }, { id: 3, statuses: [], sprints: [ { name: "Sprint 9", state: "active" } ] } ] }
    tickets = [
      ticket.("A-1", "Doing", "in_progress", [ 1, 2 ], assignee: "Me", mine: true),
      ticket.("A-2", "Doing", "in_progress", [ 1 ]),
      ticket.("A-3", "Backlog", "todo", [ 1 ]),
      ticket.("A-9", "Backlog", "todo", [ 1 ], assignee: "Me", mine: true),
      ticket.("A-8", "Parked", "todo", [ 1 ]),
      ticket.("A-4", "Verify", "post_development", [ 2 ], assignee: "Sam"),
      ticket.("A-5", "Done", "done", [ 2 ], assignee: "Me", mine: true),
      ticket.("A-6", "Doing", "in_progress", [ 3 ]).merge(sprint: "Sprint 9"),
      ticket.("A-7", "Doing", "in_progress", [ 3 ]).merge(sprint: "Sprint 10")
    ]
    stats = Dashboard.new(data: { jira_tickets: tickets, jira_boards: boards, connected: { jira: true } }, dismissed_keys: []).overview_props[:stats][:jira]

    assert_equal({ unassigned: 2, todo: 1, done: 1, boards: true }, stats, "unassigned leaves out the Backlog, hidden statuses, done and other sprints")
  end

  test "your own tickets keep the board's parent and boards when merged with the board's copy" do
    Setting[Jira::Sync::ACCOUNT_ID] = "me-1"
    JiraBoardTicket.create!(board_id: 1, key: "APP-2", position: 3, data: { "status" => "Doing", "parent_key" => "APP-1", "parent_title" => "Epic" })
    mine = [ { key: "APP-2", title: "Mine in full", description: "Details", status: "Doing", category: "in_progress" } ]

    merged = Dashboard.with_board_tickets(mine, site: "acme.example").find { it[:key] == "APP-2" }

    assert_equal [ "Mine in full", "Details", { 1 => 3 }, "APP-1" ], [ merged[:title], merged[:description], merged[:boards], merged.dig(:parent, :key) ]
  end

  test "overview limits waiting items and the review queue but reports totals" do
    props = @dashboard.overview_props

    assert_operator props[:waiting][:items].size, :<=, Dashboard::WAITING_LIMIT
    assert_operator props[:waiting][:total], :>=, props[:waiting][:items].size
    assert props[:waiting][:items].all? { it[:status] == "open" }
    assert_operator props[:review_queue][:items].size, :<=, Dashboard::REVIEW_QUEUE_LIMIT
  end

  test "dismissed items drop out of the open waiting list" do
    key = @dashboard.overview_props[:waiting][:items].first[:key]
    props = Dashboard.new(data: SampleData.load, dismissed_keys: [ key ]).overview_props

    assert_not_includes props[:waiting][:items].map { it[:key] }, key
  end

  test "lists required connections that are missing, ignoring optional ones" do
    assert_equal [ "GitHub", "Jira" ], Dashboard.new(dismissed_keys: []).shell_props[:missing_connections]
    assert_equal [ "Jira" ], Dashboard.new(data: { connected: { github: true } }, dismissed_keys: []).shell_props[:missing_connections]
  end

  test "nothing connected means empty lists and zero counts" do
    props = Dashboard.new(dismissed_keys: []).overview_props

    assert_empty props[:waiting][:items]
    assert_empty props[:review_queue][:items]
    assert_empty props[:agents]
    assert_equal({ agents: 0, busy: 0, tokens_used: 0 }, props[:stats][:agents])
    assert_equal({ team: 0, mine: 0, watching: 0 }, props[:stats][:github])
    assert_equal({ unassigned: 0, todo: 0, done: 0, boards: false }, props[:stats][:jira])
  end
end
