# GitHub PRs and notifications from the local sync, shaped for the dashboard.
module Github::DashboardData
  NOTIFICATION_WINDOW = 14.days
  NOTIFICATION_LIMIT = 100

  def self.pull_requests = GithubPullRequest.pluck(:data).map(&:deep_symbolize_keys)

  # Recent notifications, plus anything still waiting on you however old it is.
  def self.notifications
    waiting = GithubNotification.where(resolved_at: nil, reason: WaitingItems::GITHUB_REASONS.keys)
    recent = GithubNotification.where(occurred_at: NOTIFICATION_WINDOW.ago..).order(occurred_at: :desc).limit(NOTIFICATION_LIMIT)
    (recent.to_a | waiting.to_a).sort_by { -it.occurred_at.to_i }.map do |n|
      repo, number = n.pr_key.split("#")
      { id: "github-#{n.thread_id}", reason: n.reason, pr_key: n.pr_key, title: n.title, actor: n.actor, body: n.body, at: n.occurred_at,
        unread: n.read_at.nil?, resolution: n.resolution, url: "https://github.com/#{repo}/pull/#{number}" }
    end
  end
end
