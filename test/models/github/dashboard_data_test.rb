require "test_helper"

class Github::DashboardDataTest < ActiveSupport::TestCase
  test "keeps anything still waiting on you, however old, and drops old news" do
    GithubNotification.create!(thread_id: "review-a#1", reason: "review_requested", pr_key: "acme/app#1", occurred_at: 2.months.ago)
    GithubNotification.create!(thread_id: "1", reason: "comment", pr_key: "acme/app#2", occurred_at: 2.months.ago)
    GithubNotification.create!(thread_id: "2", reason: "comment", pr_key: "acme/app#3", occurred_at: 1.day.ago)
    GithubNotification.create!(thread_id: "review-a#4", reason: "review_requested", pr_key: "acme/app#4", occurred_at: 2.months.ago, resolved_at: 1.day.ago)

    assert_equal %w[github-2 github-review-a#1], Github::DashboardData.notifications.map { it[:id] }
  end
end
