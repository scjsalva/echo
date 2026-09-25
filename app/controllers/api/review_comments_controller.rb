class Api::ReviewCommentsController < ApplicationController
  # Your own comment on a line.
  def create
    review = Review.find(params[:review_id])
    comment = review.comments.create!(params.permit(:path, :line, :side, :body).merge(author: "you"))
    render json: camelize(comment.to_props), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_content
  end

  EDITABLE_STATES = %w[staged committed removed].freeze

  # Edit, commit, un-commit or remove a comment. Once a review is sent it's GitHub's.
  def update
    comment = ReviewComment.find(params[:id])
    return render(json: { error: "This review was already sent" }, status: :unprocessable_content) if comment.review.status == "sent"
    return head :unprocessable_content if params.key?(:state) && !EDITABLE_STATES.include?(params[:state])

    comment.update!(params.permit(:body, :state))
    render json: camelize(comment.to_props)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_content
  end
end
