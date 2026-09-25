class Api::GithubPullRequestsController < ApplicationController
  def index
    render json: camelize(Dashboard.current.github_props)
  end
end
