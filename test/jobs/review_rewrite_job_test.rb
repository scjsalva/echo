require "test_helper"

class ReviewRewriteJobTest < ActiveJob::TestCase
  setup do
    @comment = Review.for("acme/app#7").comments.create!(path: "app/x.rb", line: 2, side: "RIGHT", body: "The method lacks a nil guard.", author: "ai", asking: true)
  end

  test "puts the rewrite in the comment's notes, ready to use" do
    Rewriter.stub(:skill, Data.define(:name).new("in-my-words")) do
      Rewriter.stub(:rewrite, ->(text) { "Can we add a nil check? (#{text})" }) { ReviewRewriteJob.perform_now(@comment) }
    end

    assert_equal [ [ "you", "Rewrite" ], [ "claude", "Can we add a nil check? (The method lacks a nil guard.)" ] ], @comment.reload.notes.map { it.values_at("role", "text") }
    assert_not @comment.asking
  end

  test "says why it couldn't" do
    Rewriter.stub(:rewrite, ->(_) { raise Rewriter::Error, "Choose a skill for Rewrite in your words in Settings first" }) { ReviewRewriteJob.perform_now(@comment) }

    assert_equal "error", @comment.reload.notes.last["role"]
    assert_not @comment.asking
  end
end
