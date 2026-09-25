require "test_helper"

class ReviewSubmissionTest < ActiveSupport::TestCase
  setup do
    @review = Review.for("acme/app#7")
    @review.update!(head_sha: "abc123")
    @review.comments.create!(path: "app/x.rb", line: 2, side: "RIGHT", body: "Fix this", state: "committed")
    @review.comments.create!(path: "app/x.rb", line: 3, side: "RIGHT", body: "Still thinking", state: "staged")
  end

  test "sends only committed comments, with the decision and summary, then marks everything sent" do
    sent = nil
    cli = lambda do |*args, json:, input: nil|
      next { "merged" => false } unless input

      sent = [ args, JSON.parse(input) ]
      { "html_url" => "https://github.com/acme/app/pull/7#pullrequestreview-1" }
    end

    Github::Cli.stub(:run, cli) { ReviewSubmission.send!(@review, event: "request_changes", body: "A couple of things") }

    args, payload = sent
    assert_equal %w[api -X POST repos/acme/app/pulls/7/reviews --input -], args
    assert_equal({ "event" => "REQUEST_CHANGES", "body" => "A couple of things", "commit_id" => "abc123",
      "comments" => [ { "path" => "app/x.rb", "line" => 2, "side" => "RIGHT", "body" => "Fix this" } ] }, payload)
    assert_equal "sent", @review.reload.status
    assert_equal %w[sent staged], @review.comments.pluck(:state)
  end

  test "passes on GitHub's reason when it refuses" do
    error = Github::Cli::Error.new('gh: Unprocessable Entity (HTTP 422) {"message":"Can not approve your own pull request"}')

    Github::Cli.stub(:run, ->(*, **) { raise error }) do
      failure = assert_raises(ReviewSubmission::Error) { ReviewSubmission.send!(@review, event: "approve", body: "") }
      assert_equal "Can not approve your own pull request", failure.message
    end
    assert_equal "draft", @review.reload.status
  end

  test "refuses a PR that's already merged, without posting" do
    posted = false
    cli = ->(*args, json:, input: nil) { posted ||= input.present?; { "merged" => true } }

    Github::Cli.stub(:run, cli) do
      failure = assert_raises(ReviewSubmission::Error) { ReviewSubmission.send!(@review, event: "comment", body: "Late") }
      assert_match "already merged", failure.message
    end
    assert_not posted
    assert_equal "draft", @review.reload.status
  end

  test "needs something to send" do
    @review.comments.update_all(state: "staged")

    assert_raises(ReviewSubmission::Error) { ReviewSubmission.send!(@review, event: "comment", body: "") }
  end
end
