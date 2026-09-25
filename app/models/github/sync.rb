# Pulls your PRs, reviews requested from you, the watched repos' open PRs and
# GitHub's unread notifications through gh, and keeps Echo's copies and
# waiting-on-you items up to date. GithubSyncJob runs it every minute; the
# first sync marks everything already there as read.
class Github::Sync
  QUERY = Rails.root.join("lib/github/pull_requests.graphql").read.freeze
  SYNCED_AT = "github_synced_at".freeze
  NOTIFICATION_TYPES = %w[PullRequest].freeze
  PR_PATH = %r{repos/(?<repo>[^/]+/[^/]+)/pulls/(?<number>\d+)\z}

  def self.synced_at = Setting[SYNCED_AT]&.then { Time.zone.parse(it) }

  def run
    @first_sync = self.class.synced_at.nil?
    started_at = Time.current

    sync_pull_requests
    sync_notifications
    track_review_requests
    track_changes_requested
    track_new_commits
    resolve_waiting

    Setting[SYNCED_AT] = started_at.iso8601
  end

  private

  def me = @me ||= Github::Connection.login

  def sync_pull_requests
    repos = Github::Preferences.repos
    data = Github::Cli.run("api", "graphql", "-f", "query=#{QUERY}",
      "-f", "mine=is:pr is:open author:@me archived:false",
      "-f", "requested=is:pr is:open review-requested:@me archived:false",
      "-f", "queue=is:pr is:open draft:false -author:@me archived:false #{repos.map { "repo:#{it}" }.join(' ')}",
      "-F", "withQueue=#{repos.any?}", json: true).fetch("data")
    @me = data.dig("viewer", "login")

    requested_keys = nodes(data, "requested").map { key_of(it) }.to_set
    prs = %w[mine requested queue].flat_map { nodes(data, it) }.uniq { key_of(it) }
      .map { Github::PullRequest.from_graphql(it, me:, requested: requested_keys.include?(key_of(it))) }

    prs.each do |pr|
      GithubPullRequest.find_or_initialize_by(key: pr[:key]).update!(data: pr, mine: pr[:mine], requested_from_me: pr[:requested_from_me])
    end
    GithubPullRequest.where.not(key: prs.map { it[:key] }).delete_all
    @pull_requests = prs.index_by { it[:key] }
  end

  def nodes(data, name) = Array(data.dig(name, "nodes")).select { it["number"] }
  def key_of(node) = "#{node.dig('repository', 'nameWithOwner')}##{node['number']}"

  # GitHub's inbox: one thread per PR, updated whenever there's new activity on it.
  def sync_notifications
    threads = Github::Cli.run("api", "notifications?per_page=50", json: true)
    threads.select { NOTIFICATION_TYPES.include?(it.dig("subject", "type")) }.each { record_thread(it) }
  end

  def record_thread(thread)
    path = thread.dig("subject", "url").to_s.match(PR_PATH) or return
    occurred_at = Time.zone.parse(thread["updated_at"])
    row = GithubNotification.find_or_initialize_by(thread_id: thread["id"])
    return if row.persisted? && row.occurred_at >= occurred_at

    actor, body, activity = latest_comment(thread) || latest_activity(path)
    return row.update!(reason: thread["reason"], pr_key: "#{path[:repo]}##{path[:number]}", occurred_at:, read_at: Time.current) if activity == :covered
    # Your own activity and bots' (CI reports and the like) aren't news.
    return row.update!(reason: thread["reason"], pr_key: "#{path[:repo]}##{path[:number]}", occurred_at:, read_at: Time.current) if actor == me || actor.to_s.end_with?("[bot]")

    # Review requests are tracked from who's currently requested (track_review_requests),
    # so the thread only counts for what else happened on it.
    reason = activity || (thread["reason"] == "review_requested" ? "comment" : thread["reason"])
    return if reason == "comment" && body.blank?

    row.update!(reason:, pr_key: "#{path[:repo]}##{path[:number]}", title: thread.dig("subject", "title"),
      actor:, body:, occurred_at:, read_at: (Time.current if @first_sync), resolved_at: nil, resolution: nil)
  end

  def latest_comment(thread)
    url = thread.dig("subject", "latest_comment_url").presence or return
    return if url == thread.dig("subject", "url") # Points at the PR itself when the activity wasn't a comment.

    comment = Github::Cli.run("api", url.delete_prefix("https://api.github.com/"), json: true)
    [ comment.dig("user", "login"), comment["body"].to_s.squish.truncate(2_000) ]
  rescue Github::Cli::Error
    nil
  end

  # A review requested from you waits on you until you're no longer requested.
  def track_review_requests
    @pull_requests.each_value.select { it[:requested_from_me] }.each do |pr|
      GithubNotification.create_with(reason: "review_requested", pr_key: pr[:key], title: pr[:title], actor: pr[:author],
        occurred_at: Time.zone.parse(pr[:updated]), read_at: (Time.current if @first_sync))
        .find_or_create_by!(thread_id: "review-#{pr[:key]}")
    end
  end

  # GitHub's inbox says a PR had activity but only links a comment when there
  # was one. Otherwise the latest review, or the PR's own state, says what happened.
  ACTIVITY_WINDOW = 15.minutes

  def latest_activity(path)
    repo, number = path.values_at(:repo, :number)
    review = Array(Github::Cli.run("api", "repos/#{repo}/pulls/#{number}/reviews?per_page=100", json: true))
      .reject { it.dig("user", "login") == me }.max_by { it["submitted_at"].to_s }
    if review && Time.zone.parse(review["submitted_at"].to_s)&.after?(ACTIVITY_WINDOW.ago)
      # Changes requested already waits on you (track_changes_requested); no need to say it twice.
      return [ nil, nil, :covered ] if review["state"] == "CHANGES_REQUESTED"

      state = { "APPROVED" => "approved", "COMMENTED" => "reviewed", "DISMISSED" => "review_dismissed" }.fetch(review["state"], "reviewed")
      return [ review.dig("user", "login"), review["body"].to_s.squish.truncate(2_000).presence, state ]
    end

    pr = Github::Cli.run("api", "repos/#{repo}/pulls/#{number}", json: true)
    if pr["merged_at"]
      # Merging your own PR isn't news.
      return pr.dig("merged_by", "login") == me ? [ nil, nil, :covered ] : [ pr.dig("merged_by", "login"), nil, "merged" ]
    end
    return [ nil, nil, "closed" ] if pr["state"] == "closed"

    nil
  rescue Github::Cli::Error
    nil
  end

  # Changes requested on your PR wait on you until you push again.
  def track_changes_requested
    @pull_requests.each_value.select { it[:mine] && it[:review_state] == "changes_requested" }.each do |pr|
      review = pr[:reviews].select { it[:state] == "changes_requested" }.max_by { it[:submitted_at].to_s } or next
      at = Time.zone.parse(review[:submitted_at])
      GithubNotification.create_with(reason: "changes_requested", pr_key: pr[:key], title: pr[:title], actor: review[:login],
        body: review[:body].to_s.squish.truncate(2_000).presence, occurred_at: at, read_at: (Time.current if @first_sync))
        .find_or_create_by!(thread_id: "changes-#{pr[:key]}-#{at.to_i}")
    end
  end

  # Someone pushed to a PR after you reviewed it.
  def track_new_commits
    @pull_requests.each_value.reject { it[:mine] }.each do |pr|
      mine = pr[:reviews].find { it[:login] == me } or next
      next unless pr[:last_commit_at] && pr[:last_commit_at] > mine[:submitted_at].to_s

      at = Time.zone.parse(pr[:last_commit_at])
      GithubNotification.create_with(reason: "follow_up", pr_key: pr[:key], title: pr[:title], actor: pr[:author],
        body: "Pushed new commits after your review", occurred_at: at, read_at: (Time.current if @first_sync))
        .find_or_create_by!(thread_id: "follow-up-#{pr[:key]}-#{at.to_i}")
    end
  end

  def resolve_waiting
    open = GithubNotification.where(resolved_at: nil)

    open.where(reason: "review_requested").find_each do |n|
      pr = @pull_requests[n.pr_key]
      resolve(n, pr&.dig(:reviews)&.any? { it[:login] == me } ? "You reviewed it" : "No longer requested from you") unless pr&.dig(:requested_from_me)
    end

    open.where(reason: "changes_requested").find_each do |n|
      pr = @pull_requests[n.pr_key]
      resolve(n, "You pushed new commits") if pr.nil? || pr[:review_state] != "changes_requested" || pr[:last_commit_at].to_s > n.occurred_at.iso8601
    end

    open.where(reason: %w[mention team_mention]).find_each { |n| resolve(n, "You replied on GitHub") if replied_since?(n) }
  end

  # Checks the PR's comments and reviews for anything you wrote after the mention.
  def replied_since?(notification)
    repo, number = notification.pr_key.split("#")
    since = notification.occurred_at.iso8601
    [ "repos/#{repo}/issues/#{number}/comments?since=#{since}", "repos/#{repo}/pulls/#{number}/comments?since=#{since}" ]
      .any? { |path| Array(Github::Cli.run("api", path, json: true)).any? { it.dig("user", "login") == me } } ||
      Array(Github::Cli.run("api", "repos/#{repo}/pulls/#{number}/reviews", json: true))
        .any? { it.dig("user", "login") == me && it["submitted_at"].to_s > since }
  rescue Github::Cli::Error
    false
  end

  def resolve(notification, resolution) = notification.update!(resolved_at: Time.current, resolution:)
end
