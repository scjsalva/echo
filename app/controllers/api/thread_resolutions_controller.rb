# Resolves or unresolves an earlier review thread on GitHub.
class Api::ThreadResolutionsController < ApplicationController
  def create
    review = Review.find(params[:review_id])
    thread = Github::ReviewThreads.find(review.repo, review.number, params[:thread_id].to_s)
    return render(json: { error: "That thread isn't on this PR" }, status: :unprocessable_content) unless thread

    Github::ReviewThreadActions.resolve(thread[:id], resolved: ActiveModel::Type::Boolean.new.cast(params[:resolved]))
    Github::ReviewThreads.forget(review.repo, review.number)
    render json: camelize(threads: Github::ReviewThreads.all(review.repo, review.number))
  rescue Github::Cli::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
