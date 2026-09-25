class ReviewsController < ApplicationController
  def show
    repo = "#{params[:owner]}/#{params[:repo]}"
    live = Github::Cli.run("api", "repos/#{repo}/pulls/#{params[:number]}", json: true)
    review = Review.for("#{repo}##{params[:number]}")
    review.update!(head_sha: live.dig("head", "sha")) if review.head_sha.blank?

    @props = {
      shell: Dashboard.current.shell_props, agents: [],
      pull_request: GithubPullRequest.find_by(key: review.pr_key)&.data || Github::PullRequest.from_rest(live, me: Github::Connection.login),
      head_sha: live.dig("head", "sha"), merged_at: (live["merged_at"] if live["merged"]), files: Github::PullRequestFiles.fetch(repo, params[:number]), review: review.to_props
    }
  rescue Github::Cli::Error => e
    @props = { shell: Dashboard.current.shell_props, agents: [], error: e.message }
  end
end
