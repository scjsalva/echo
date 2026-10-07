require "test_helper"

class Github::CliTest < ActiveSupport::TestCase
  test "allows reads, GraphQL queries and marking a notification read, and nothing else" do
    allowed = [ %w[auth status], %w[api notifications?per_page=50], %w[api -H Accept:x repos/a/b/issues/comments/1],
      [ "api", "graphql", "-f", "query=query { viewer { login } }" ], %w[api -X PATCH notifications/threads/123] ]
    refused = [ [ "api", "graphql", "-f", "query=mutation { addStar(input: {}) { clientMutationId } }" ],
      %w[api -X PATCH repos/a/b/pulls/1], %w[api -X POST notifications/threads/1], %w[api --method DELETE repos/a/b], %w[pr merge 1] ]

    allowed.each { assert Github::Cli.allowed?(it), "should allow #{it.join(' ')}" }
    refused.each { assert_not Github::Cli.allowed?(it), "should refuse #{it.join(' ')}" }
  end

  test "lets through only the exact mutations for replying to, resolving and unresolving a review thread" do
    Github::ReviewThreadActions::MUTATIONS.each do |mutation|
      assert Github::Cli.allowed?([ "api", "graphql", "-f", "query=#{mutation}", "-f", "thread=T_1" ])
    end
    tweaked = Github::ReviewThreadActions::REPLY.sub("{ comment { url } }", "{ comment { url } } deletePullRequestReviewComment(input: {id: 1}) { clientMutationId }")
    assert_not Github::Cli.allowed?([ "api", "graphql", "-f", "query=#{tweaked}" ])
  end

  test "is connected when gh is logged in, with the account" do
    ENV["FAKE_GH_LOGGED_IN"] = "1"
    Github::Connection.refresh!

    assert_equal [ true, "octo" ], Github::Connection.status.values_at(:connected, :login)
  ensure
    ENV.delete("FAKE_GH_LOGGED_IN")
  end
end
