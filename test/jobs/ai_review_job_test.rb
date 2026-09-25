require "test_helper"

class AiReviewJobTest < ActiveJob::TestCase
  test "waits for a free slot instead of starting over the limit" do
    Review.limit = 1
    Review.create!(pr_key: "acme/app#100", ai_status: "running")
    review = Review.create!(pr_key: "acme/app#1", ai_status: "queued")

    AiReviewer.stub(:run, ->(*) { flunk "shouldn't start" }) do
      assert_enqueued_with(job: AiReviewJob) { AiReviewJob.perform_now(review) }
    end
    assert_equal "queued", review.reload.ai_status
  end

  test "runs once a slot is free" do
    review = Review.create!(pr_key: "acme/app#1", ai_status: "queued")

    AiReviewer.stub(:run, ->(*) { assert_equal "running", review.reload.ai_status }) { AiReviewJob.perform_now(review) }

    assert_equal "done", review.reload.ai_status
  end
end
