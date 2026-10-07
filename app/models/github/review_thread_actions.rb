# The only things Echo does to an existing review thread on GitHub: reply to it,
# resolve it, or unresolve it. Each is one fixed GraphQL mutation, and these are
# the only mutations Github::Cli lets through.
module Github::ReviewThreadActions
  REPLY = <<~GRAPHQL.squish.freeze
    mutation($thread: ID!, $body: String!) {
      addPullRequestReviewThreadReply(input: { pullRequestReviewThreadId: $thread, body: $body }) { comment { url } }
    }
  GRAPHQL
  RESOLVE = <<~GRAPHQL.squish.freeze
    mutation($thread: ID!) { resolveReviewThread(input: { threadId: $thread }) { thread { isResolved } } }
  GRAPHQL
  UNRESOLVE = <<~GRAPHQL.squish.freeze
    mutation($thread: ID!) { unresolveReviewThread(input: { threadId: $thread }) { thread { isResolved } } }
  GRAPHQL
  MUTATIONS = [ REPLY, RESOLVE, UNRESOLVE ].freeze

  # Returns the reply's URL on GitHub.
  def self.reply(thread_id, body)
    result = run(REPLY, "thread=#{thread_id}", "body=#{body}")
    result.dig("data", "addPullRequestReviewThreadReply", "comment", "url")
  end

  def self.resolve(thread_id, resolved:) = run(resolved ? RESOLVE : UNRESOLVE, "thread=#{thread_id}")

  def self.run(mutation, *fields)
    result = Github::Cli.run("api", "graphql", "-f", "query=#{mutation}", *fields.flat_map { [ "-f", it ] }, json: true)
    raise Github::Cli::Error, result["errors"].map { it["message"] }.join("; ") if result["errors"].present?

    result
  end

  private_class_method :run
end
