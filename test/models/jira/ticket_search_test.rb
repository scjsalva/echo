require "test_helper"

class Jira::TicketSearchTest < ActiveSupport::TestCase
  def search(**options)
    jql = nil
    results = Array.new(11) { |i| { "key" => "APP-#{i}", "fields" => { "summary" => "T#{i}", "status" => { "name" => "Done", "statusCategory" => { "key" => "done" } } } } }
    page = Jira::Cli.stub(:run, ->(*args, json:) { jql = args[args.index("--jql") + 1]; results }) { Jira::TicketSearch.page(site: "x.atlassian.net", **options) }
    [ jql, page ]
  end

  test "pages your done tickets, skipping the ones already shown" do
    jql, page = search(scope: "watching", done: true, type: "Bug", seen: %w[APP-9 bad;key])

    assert_equal 'watcher = currentUser() AND statusCategory = Done AND issuetype = "Bug" AND key NOT IN (APP-9) ORDER BY updated DESC', jql
    assert_equal 10, page[:items].size
    assert page[:more]
    assert_equal [ "https://x.atlassian.net/browse/APP-0", "done" ], page[:items].first.values_at(:url, :category)
  end

  test "searches all of Jira by text, or by key when the query is one" do
    assert_equal 'text ~ "say hi" ORDER BY updated DESC', search(query: 'say "hi"').first
    assert_equal "key = APP-41029 ORDER BY updated DESC", search(query: "app-41029").first
  end

  test "refuses an unscoped search with no query, and unknown scopes" do
    assert_raises(ArgumentError) { Jira::TicketSearch.page(site: "x") }
    assert_raises(KeyError) { Jira::TicketSearch.page(site: "x", scope: "everyone") }
  end
end
