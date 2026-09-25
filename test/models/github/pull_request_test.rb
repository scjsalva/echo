require "test_helper"

class Github::PullRequestTest < ActiveSupport::TestCase
  test "summarises the description's first paragraph, skipping template comments and headings" do
    body = "<!-- Describe your change -->\n## What\n\nLabels the **default** language fields.\n\nMore detail."

    assert_equal "Labels the default language fields.", Github::PullRequest.summary(body)
  end

  test "maps CI and review state, and finds the Jira key in the title" do
    node = { "number" => 5, "title" => "[APP-41029] Label fields", "url" => "u", "isDraft" => false, "reviewDecision" => "APPROVED",
      "author" => { "login" => "me" }, "repository" => { "nameWithOwner" => "acme/app" },
      "commits" => { "totalCount" => 2, "nodes" => [ { "commit" => { "statusCheckRollup" => { "state" => "FAILURE" } } } ] },
      "latestReviews" => { "nodes" => [ { "author" => { "login" => "dana" }, "state" => "APPROVED" } ] } }

    pr = Github::PullRequest.from_graphql(node, me: "me")

    assert_equal [ "acme/app#5", "app", "APP-41029", "failing", "approved", 1, true ], pr.values_at(:key, :repo, :jira_key, :ci, :review_state, :approvals, :mine)
  end

  test "keeps the whole description, minus template comments" do
    assert_equal "## What\n\nLabels fields.\n\n- [x] Tests", Github::PullRequest.description("<!-- template -->\n## What\n\n\n\nLabels fields.\n\n- [x] Tests")
    assert_nil Github::PullRequest.description("<!-- only a template -->")
  end
end
