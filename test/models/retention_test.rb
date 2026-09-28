require "test_helper"

class RetentionTest < ActiveSupport::TestCase
  test "forgets old notifications, but keeps anything still waiting on you" do
    GithubNotification.create!(thread_id: "old-merge", reason: "merged", pr_key: "acme/app#1", occurred_at: 40.days.ago)
    GithubNotification.create!(thread_id: "old-request", reason: "review_requested", pr_key: "acme/app#2", occurred_at: 40.days.ago)
    GithubNotification.create!(thread_id: "old-done", reason: "mention", pr_key: "acme/app#3", occurred_at: 40.days.ago, resolved_at: 35.days.ago)
    GithubNotification.create!(thread_id: "recent", reason: "merged", pr_key: "acme/app#4", occurred_at: 2.days.ago)

    Retention.run

    assert_equal %w[old-request recent], GithubNotification.order(:thread_id).pluck(:thread_id)
  end

  test "forgets sent reviews and untouched drafts after 30 days" do
    old_sent = Review.create!(pr_key: "acme/app#1", status: "sent", sent_at: 40.days.ago)
    old_sent.comments.create!(path: "a.rb", line: 1, side: "RIGHT", body: "Hmm", state: "sent")
    fresh = Review.create!(pr_key: "acme/app#2")
    Review.create!(pr_key: "acme/app#3").update_columns(updated_at: 40.days.ago)

    Retention.run

    assert_equal [ fresh.id ], Review.pluck(:id)
    assert_empty ReviewComment.where(review_id: old_sent.id)
  end

  test "forgets ended Claude runs a day on" do
    SpawnedAgent.create!(pid: 1, purpose: "summary", ended_at: 2.days.ago)
    SpawnedAgent.create!(pid: 2, purpose: "summary", ended_at: 1.hour.ago)
    SpawnedAgent.create!(pid: 3, purpose: "ai_review")

    Retention.run

    assert_equal [ 2, 3 ], SpawnedAgent.order(:pid).pluck(:pid)
  end
end
