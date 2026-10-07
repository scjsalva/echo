class AiReviewJob < ApplicationJob
  WAIT_FOR_SLOT = 10.seconds

  def perform(review)
    return retry_job(wait: WAIT_FOR_SLOT) unless review.claim_slot

    Changes.bump
    AiReviewer.run(review)
    review.update!(ai_status: "done", ai_error: nil, ai_finished_at: Time.current)
  rescue AiReviewer::Error, Github::Cli::Error, Github::Checkout::Error => e
    review.update!(ai_status: "failed", ai_error: e.message, ai_finished_at: Time.current)
  ensure
    Changes.bump if review.reload.ai_status != "queued"
  end
end
