# One pull request from GitHub's GraphQL API, shaped for the dashboard.
module Github::PullRequest
  CI = { "SUCCESS" => "passing", "FAILURE" => "failing", "ERROR" => "failing" }.freeze
  REVIEW = { "APPROVED" => "approved", "CHANGES_REQUESTED" => "changes_requested" }.freeze
  JIRA_KEY = /\b([A-Z][A-Z0-9_]+-\d+)\b/

  def self.from_graphql(node, me:, requested: false)
    full_name = node.dig("repository", "nameWithOwner")
    reviews = Array(node.dig("latestReviews", "nodes")).map do |r|
      { login: r.dig("author", "login"), state: r["state"].downcase, submitted_at: r["submittedAt"], body: r["body"] }
    end
    last_commit = node.dig("commits", "nodes", 0, "commit") || {}

    {
      key: "#{full_name}##{node['number']}", repo: full_name.split("/").last, full_name:, number: node["number"], url: node["url"],
      jira_key: node["title"][JIRA_KEY, 1], title: node["title"], summary: summary(node["body"]), description: description(node["body"]),
      author: node.dig("author", "login"), mine: node.dig("author", "login") == me, draft: node["isDraft"],
      ci: CI.fetch(last_commit.dig("statusCheckRollup", "state"), "running"),
      review_state: node["isDraft"] ? "draft" : REVIEW.fetch(node["reviewDecision"], "review_required"),
      approvals: reviews.count { it[:state] == "approved" }, approvals_required: nil,
      requested_from_me: requested, opened: node["createdAt"], updated: node["updatedAt"],
      # When it became reviewable: marked ready, or opened that way.
      ready_at: node.dig("readyEvents", "nodes", 0, "createdAt") || node["createdAt"],
      additions: node["additions"], deletions: node["deletions"], changed_files: node["changedFiles"],
      commits: node.dig("commits", "totalCount"), last_commit_at: last_commit["committedDate"], reviews:,
      requested_reviewers: Array(node.dig("reviewRequests", "nodes")).filter_map { it.dig("requestedReviewer", "login") || it.dig("requestedReviewer", "slug") }
    }
  end

  # The same shape from the REST API, for PRs Echo hasn't synced (e.g. opened from a link).
  def self.from_rest(pr, me:)
    full_name = pr.dig("base", "repo", "full_name")
    {
      key: "#{full_name}##{pr['number']}", repo: full_name.split("/").last, full_name:, number: pr["number"], url: pr["html_url"],
      jira_key: pr["title"][JIRA_KEY, 1], title: pr["title"], summary: summary(pr["body"]), description: description(pr["body"]),
      author: pr.dig("user", "login"), mine: pr.dig("user", "login") == me, draft: pr["draft"], ci: "running",
      review_state: pr["draft"] ? "draft" : "review_required", approvals: 0, approvals_required: nil, requested_from_me: false,
      opened: pr["created_at"], updated: pr["updated_at"], additions: pr["additions"], deletions: pr["deletions"],
      changed_files: pr["changed_files"], commits: pr["commits"], reviews: []
    }
  end

  # The full description as written, minus PR-template comments.
  def self.description(body) = body.to_s.gsub(/<!--.*?-->/m, "").gsub(/\n{3,}/, "\n\n").strip.presence

  # The description's opening paragraph, without markdown noise or HTML comments (PR templates).
  def self.summary(body)
    text = body.to_s.gsub(/<!--.*?-->/m, "").gsub(/!\[[^\]]*\]\([^)]*\)/, "").strip
    paragraph = text.split(/\n\s*\n/).find { it.present? && !it.start_with?("#") }.to_s
    paragraph.gsub(/[*_`>]/, "").squish.truncate(600)
  end
end
