require "test_helper"

class Github::ReviewThreadsTest < ActiveSupport::TestCase
  def node(id, resolved:, line: 5, outdated: false)
    { "id" => id, "isResolved" => resolved, "isOutdated" => outdated, "path" => "a.rb", "line" => line, "startLine" => nil,
      "originalLine" => 5, "diffSide" => "RIGHT",
      "comments" => { "nodes" => [ { "id" => "#{id}-c", "author" => { "login" => "dana" }, "body" => "Hmm", "createdAt" => "2026-09-01T00:00:00Z", "url" => "u" } ] } }
  end

  test "keeps unresolved threads from anyone, and marks ones on changed code as outdated" do
    page = { "data" => { "repository" => { "pullRequest" => { "reviewThreads" => {
      "pageInfo" => { "hasNextPage" => false }, "nodes" => [ node("t1", resolved: false), node("t2", resolved: true), node("t3", resolved: false, line: nil, outdated: true) ]
    } } } } }
    Rails.cache.clear

    threads = Github::Cli.stub(:run, ->(*, **) { page }) { Github::ReviewThreads.unresolved("acme/app", 7) }

    assert_equal %w[t1 t3], threads.pluck(:id)
    assert_equal [ false, true ], threads.pluck(:outdated)
    assert_equal [ "dana", "Hmm" ], threads.first[:comments].first.values_at(:author, :body)
  end
end
