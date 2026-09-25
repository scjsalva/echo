class Api::GithubReviewThreadsController < ApplicationController
  def index
    render json: camelize(threads: Github::ReviewThreads.unresolved("#{params[:owner]}/#{params[:repo]}", params[:number]))
  rescue Github::Cli::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
