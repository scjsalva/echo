# A PR's conversation on GitHub, oldest first: general comments, reviews that
# say something, and comments left on lines of the diff. Fetched when you open
# the PR rather than synced, since only the open one is needed.
module Github::PullRequestComments
  CACHE_FOR = 1.minute
  PER_PAGE = 100

  def self.fetch(repo, number)
    Rails.cache.fetch([ "pr-comments", repo, number ], expires_in: CACHE_FOR) do
      (issue_comments(repo, number) + reviews(repo, number) + line_comments(repo, number)).sort_by { it[:at].to_s }
    end
  end

  def self.issue_comments(repo, number)
    get("repos/#{repo}/issues/#{number}/comments").map do |c|
      entry(c, kind: "comment", at: c["created_at"])
    end
  end

  # A review with no summary is just a state change, which the PR already shows.
  def self.reviews(repo, number)
    get("repos/#{repo}/pulls/#{number}/reviews").filter_map do |r|
      next if r["body"].blank?

      entry(r, kind: "review", at: r["submitted_at"], state: r["state"].to_s.downcase)
    end
  end

  def self.line_comments(repo, number)
    get("repos/#{repo}/pulls/#{number}/comments").map do |c|
      reply_to = c["in_reply_to_id"] && "line-#{c['in_reply_to_id']}"
      entry(c, kind: "line", at: c["created_at"], path: c["path"], line: c["line"] || c["original_line"], reply_to:)
    end
  end

  def self.entry(raw, kind:, at:, **extra)
    { id: "#{kind}-#{raw['id']}", kind:, author: raw.dig("user", "login"), bot: raw.dig("user", "type") == "Bot",
      body: raw["body"].to_s, at:, url: raw["html_url"], **extra }
  end

  def self.get(path) = Array(Github::Cli.run("api", "#{path}?per_page=#{PER_PAGE}", json: true))

  private_class_method :issue_comments, :reviews, :line_comments, :entry, :get
end
