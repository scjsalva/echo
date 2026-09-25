class Api::GithubPullRequestCommentsController < ApplicationController
  def index
    render json: camelize(comments: Github::PullRequestComments.fetch("#{params[:owner]}/#{params[:repo]}", params[:number]))
  rescue Github::Cli::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
