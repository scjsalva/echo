class Api::GithubPullRequestsController < ApplicationController
  def index
    render json: camelize(Dashboard.current.github_props)
  end

  # One PR Echo doesn't sync, e.g. merged or closed since, for its drawer.
  def show
    repo = "#{params[:owner]}/#{params[:repo]}"
    pr = Github::Cli.run("api", "repos/#{repo}/pulls/#{params[:number]}", json: true)
    reviews = Array(Github::Cli.run("api", "repos/#{repo}/pulls/#{params[:number]}/reviews", json: true)).reject { it["state"] == "PENDING" }
    latest = reviews.group_by { it.dig("user", "login") }.map { |login, rs| { login:, state: rs.last["state"].downcase } }
    render json: camelize(Github::PullRequest.from_rest(pr, me: Github::Connection.login).merge(reviews: latest))
  rescue Github::Cli::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
