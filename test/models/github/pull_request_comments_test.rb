require "test_helper"

class Github::PullRequestCommentsTest < ActiveSupport::TestCase
  RESPONSES = {
    "repos/acme/app/issues/1/comments" => [ { "id" => 1, "user" => { "login" => "ana", "type" => "User" }, "body" => "Looks good", "created_at" => "2026-09-02T10:00:00Z", "html_url" => "u1" } ],
    "repos/acme/app/pulls/1/reviews" => [
      { "id" => 2, "user" => { "login" => "bo" }, "body" => "", "state" => "APPROVED", "submitted_at" => "2026-09-01T10:00:00Z" },
      { "id" => 3, "user" => { "login" => "cy" }, "body" => "Needs a test", "state" => "CHANGES_REQUESTED", "submitted_at" => "2026-09-03T10:00:00Z" }
    ],
    "repos/acme/app/pulls/1/comments" => [
      { "id" => 4, "user" => { "login" => "dependabot", "type" => "Bot" }, "body" => "nil here?", "path" => "a.rb", "line" => 7, "created_at" => "2026-09-01T09:00:00Z" },
      { "id" => 5, "user" => { "login" => "ana", "type" => "User" }, "body" => "fixed", "path" => "a.rb", "line" => 7, "created_at" => "2026-09-01T09:30:00Z", "in_reply_to_id" => 4 }
    ]
  }.freeze

  def comments
    Rails.cache.clear
    Github::Cli.stub(:run, ->(_, path, **) { RESPONSES.fetch(path.split("?").first) }) { Github::PullRequestComments.fetch("acme/app", 1) }
  end

  test "merges comments, reviews with a summary and line comments, oldest first" do
    assert_equal %w[line-4 line-5 comment-1 review-3], comments.pluck(:id)
  end

  test "keeps where a line comment is and who wrote it" do
    line = comments.first

    assert_equal [ "a.rb", 7, true, nil ], line.values_at(:path, :line, :bot, :reply_to)
    assert_equal "changes_requested", comments.last[:state]
  end

  test "points a reply at the comment it replies to" do
    assert_equal "line-4", comments.second[:reply_to]
  end
end
