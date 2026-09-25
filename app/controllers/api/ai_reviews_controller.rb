# Starts Claude reviewing the diff in the background; the page polls for its comments.
class Api::AiReviewsController < ApplicationController
  def create
    review = Review.find(params[:review_id])
    # Already running, e.g. from a second click: report the run in progress rather than start another.
    return render(json: camelize(review.to_props)) if review.ai_status.in?(%w[queued running])
    return render(json: { error: "This PR is already merged, so it can't be reviewed" }, status: :unprocessable_content) if review.merged?

    # The job starts it once one of the limited slots is free.
    review.update!(ai_status: "queued", ai_error: nil, ai_report: nil)
    AiReviewJob.perform_later(review)
    render json: camelize(review.to_props)
  rescue Github::Cli::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
