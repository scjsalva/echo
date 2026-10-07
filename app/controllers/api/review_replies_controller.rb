# Sends one reply to its thread on GitHub now, without waiting for the review.
class Api::ReviewRepliesController < ApplicationController
  def create
    comment = ReviewComment.replies.find(params[:review_comment_id])
    return render(json: { error: "Already sent" }, status: :unprocessable_content) if comment.state == "sent"

    ReviewSubmission.send_reply!(comment)
    render json: camelize(comment.to_props)
  rescue ReviewSubmission::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
