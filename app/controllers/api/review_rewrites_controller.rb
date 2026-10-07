# Rewrites with your rewrite skill: a comment (its draft lands in its notes), or a
# review summary you're writing (the draft comes straight back).
class Api::ReviewRewritesController < ApplicationController
  def create
    if params[:review_comment_id]
      comment = ReviewComment.find(params[:review_comment_id])
      return render(json: { error: "Write something to rewrite first" }, status: :unprocessable_content) if comment.body.blank?
      return render(json: { error: "Choose a skill for Rewrite in your words in Settings first" }, status: :unprocessable_content) unless Rewriter.skill

      comment.update!(asking: true)
      ReviewRewriteJob.perform_later(comment)
      render json: camelize(comment.to_props)
    else
      render json: { text: Rewriter.rewrite(params[:text].to_s) }
    end
  rescue Rewriter::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
