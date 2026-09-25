require "test_helper"

class AiReviewerTest < ActiveSupport::TestCase
  Status = Struct.new(:success?)
  PATCH = "@@ -1,2 +1,3 @@\n a = 1\n+b = nil.size\n c = 3".freeze

  setup do
    Rails.cache.clear
    @review = Review.for("acme/app#7")
    GithubPullRequest.create!(key: "acme/app#7", data: { "title" => "Add b", "description" => "Adds b." })
  end

  def with_diff(&block)
    Github::Checkout.stub(:for_pull_request, Pathname("/tmp/checkout")) do
      Github::Cli.stub(:run, ->(*, **) { [ { "filename" => "app/x.rb", "status" => "modified", "patch" => PATCH } ] }, &block)
    end
  end

  test "stages findings on real diff lines and drops ones that aren't in the diff" do
    input_seen = nil
    answer = { structured_output: { summary: "One real bug.", findings: [
      { path: "app/x.rb", line: 2, side: "RIGHT", severity: "high", body: "nil.size raises", verified: true, evidence: "x.rb:2 calls size on nil" },
      { path: "app/x.rb", line: 2, side: "RIGHT", body: "A guess", verified: false, evidence: "" },
      { path: "app/x.rb", line: 99, side: "RIGHT", body: "Not a real line", verified: true, evidence: "x.rb:99" }
    ] } }.to_json
    command = folder = nil
    claude = ->(args, input:, chdir:, **) { input_seen, command, folder = input, args, chdir; [ answer, Status.new(true) ] }

    with_diff { ClaudeCode::Headless.stub(:run, claude) { AiReviewer.run(@review) } }

    assert_equal [ [ "app/x.rb", 2, "RIGHT", "nil.size raises", "staged", "ai", "high", "x.rb:2 calls size on nil" ] ],
      @review.comments.pluck(:path, :line, :side, :body, :state, :author, :severity, :evidence)
    assert_includes input_seen, "R2     + b = nil.size"
    assert_includes input_seen, "# Add b"
    report = @review.reload.ai_report
    assert_equal [ "One real bug.", 1 ], report.values_at("summary", "added")
    assert_equal [ "Claude couldn't confirm it in the code", "Not on a line in this diff" ], report["left_out"].pluck("reason")
    assert_equal Pathname("/tmp/checkout"), folder
    assert_includes command, "--restricted"
    system_prompt = command[command.index("--system-prompt") + 1]
    assert_includes system_prompt, "Find real problems"
    assert_includes system_prompt, "## Echo's rules"
    assert_equal "Read,Grep,Glob", command[command.index("--tools") + 1]
  end

  test "an empty answer is a failure, not a clean review" do
    with_diff do
      ClaudeCode::Headless.stub(:run, ->(*, **) { [ { structured_output: { summary: " ", findings: [] } }.to_json, Status.new(true) ] }) do
        error = assert_raises(AiReviewer::Error) { AiReviewer.run(@review) }
        assert_match "without saying anything", error.message
      end
    end
    assert_nil @review.reload.ai_report
  end

  test "reports a failed run" do
    with_diff do
      ClaudeCode::Headless.stub(:run, ->(*, **) { [ "Not logged in", Status.new(false) ] }) do
        assert_raises(AiReviewer::Error) { AiReviewer.run(@review) }
      end
    end
  end
end
