class AiReviewJob < ApplicationJob
  def perform(review)
    AiReviewer.run(review)
    review.update!(ai_status: "done", ai_error: nil)
  rescue AiReviewer::Error, Github::Cli::Error, Github::Checkout::Error => e
    review.update!(ai_status: "failed", ai_error: e.message)
  ensure
    Changes.bump
  end
end
