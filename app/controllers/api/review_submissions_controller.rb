# Sends the review to GitHub. This is the only point where anything is posted.
class Api::ReviewSubmissionsController < ApplicationController
  def create
    review = Review.find(params[:review_id])
    ReviewSubmission.send!(review, event: params[:event].to_s, body: params[:body].to_s)
    render json: camelize(review.to_props)
  rescue ReviewSubmission::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
