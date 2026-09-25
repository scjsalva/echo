require "test_helper"

class DashboardTest < ActiveSupport::TestCase
  setup { @dashboard = Dashboard.new(data: SampleData.load, dismissed_keys: []) }

  test "review queue excludes my PRs, drafts and unwatched repos, newest first" do
    queue = @dashboard.review_queue

    assert queue.none? { it[:mine] || it[:draft] }
    assert queue.all? { %w[web editor assistant].include?(it[:repo]) }
    opened = queue.map { Time.zone.parse(it[:opened].to_s) }
    assert_equal opened.sort.reverse, opened

    synced = Dashboard.new(data: SampleData.load.merge(pull_requests: SampleData.load[:pull_requests].map { it.merge(opened: it[:opened].iso8601) }), dismissed_keys: [])
    assert_equal opened, synced.review_queue.map { Time.zone.parse(it[:opened]) }
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
    assert_equal({ open: 0, done: 0 }, props[:stats][:jira])
  end
end
