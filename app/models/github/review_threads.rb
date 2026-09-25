# Earlier review comments on a PR's lines that are still unresolved, from any
# author, so a new review sees what's already been raised. Resolved threads are
# left out. GitHub's REST API doesn't say whether a thread is resolved, so this
# uses its GraphQL API (read only).
module Github::ReviewThreads
  CACHE_FOR = 1.minute
  QUERY = <<~GRAPHQL.freeze
    query($owner: String!, $name: String!, $number: Int!, $after: String) {
      repository(owner: $owner, name: $name) {
        pullRequest(number: $number) {
          reviewThreads(first: 100, after: $after) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id isResolved isOutdated path line startLine originalLine diffSide
              comments(first: 50) { nodes { id author { login } body createdAt url } }
            }
          }
        }
      }
    }
  GRAPHQL
  MAX_PAGES = 5

  def self.unresolved(repo, number)
    Rails.cache.fetch([ "pr-threads", repo, number ], expires_in: CACHE_FOR) do
      owner, name = repo.split("/")
      threads = []
      after = nil
      MAX_PAGES.times do
        args = [ "api", "graphql", "-f", "query=#{QUERY}", "-f", "owner=#{owner}", "-f", "name=#{name}", "-F", "number=#{number.to_i}" ]
        args += [ "-f", "after=#{after}" ] if after
        page = Github::Cli.run(*args, json: true).dig("data", "repository", "pullRequest", "reviewThreads") || {}
        threads += Array(page["nodes"])
        break unless page.dig("pageInfo", "hasNextPage")

        after = page.dig("pageInfo", "endCursor")
      end
      threads.reject { it["isResolved"] }.map { shape(it) }
    end
  end

  # An outdated thread's line is gone from the current diff, so it keeps the line it was left on.
  def self.shape(thread)
    {
      id: thread["id"], path: thread["path"], side: thread["diffSide"], line: thread["line"], start_line: thread["startLine"],
      outdated: thread["isOutdated"] || thread["line"].nil?, original_line: thread["originalLine"],
      comments: Array(thread.dig("comments", "nodes")).map do |c|
        { id: c["id"], author: c.dig("author", "login"), body: c["body"].to_s, at: c["createdAt"], url: c["url"] }
      end
    }
  end

  private_class_method :shape
end
