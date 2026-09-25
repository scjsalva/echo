# Asks Claude about one comment; the answer lands in the comment's notes.
class Api::ReviewQuestionsController < ApplicationController
  def create
    comment = ReviewComment.find(params[:review_comment_id])
    question = params[:question].to_s.strip
    return render(json: { error: "Ask something" }, status: :unprocessable_content) if question.blank?

    comment.update!(asking: true)
    ReviewQuestionJob.perform_later(comment, question)
    render json: camelize(comment.to_props)
  end
end
