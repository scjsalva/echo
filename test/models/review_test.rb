require "test_helper"

class ReviewTest < ActiveSupport::TestCase
  def running(n) = Array.new(n) { |i| Review.create!(pr_key: "acme/app##{100 + i}", ai_status: "running") }

  test "only as many reviews run at once as the limit allows" do
    Review.limit = 2
    running(2)
    waiting = Review.create!(pr_key: "acme/app#1", ai_status: "queued")

    assert_not waiting.claim_slot
    assert_equal "queued", waiting.reload.ai_status

    Review.limit = 3
    assert waiting.claim_slot
    assert_equal "running", waiting.reload.ai_status
  end

  test "a review stuck running after a restart gives its slot back" do
    Review.limit = 1
    stuck = running(1).first
    stuck.update_columns(updated_at: 1.hour.ago)
    waiting = Review.create!(pr_key: "acme/app#1", ai_status: "queued")

    assert waiting.claim_slot
    assert_equal "failed", stuck.reload.ai_status
    assert_match "interrupted", stuck.ai_error
  end

  test "the limit is 1 to 5, and 3 until you choose" do
    assert_equal 3, Review.limit
    assert_raises(ArgumentError) { Review.limit = 9 }
  end
end
