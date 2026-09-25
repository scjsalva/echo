require "test_helper"

class ClaudeCode::SummaryTest < ActiveSupport::TestCase
  include FakeClaudeHome

  setup do
    setup_claude_home
    append_transcript(human("fix login"), *assistant(id: "m1", blocks: [ { type: "text", text: "Fixed it." } ]))
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @cache
    teardown_claude_home
  end

  test "asks Haiku with the recent conversation and caches the result until the transcript grows" do
    calls = []
    fake = ->(command, input:, **) { calls << [ command, input ]; [ "Fixing login. Done.\n", Struct.new(:success?).new(true) ] }

    ClaudeCode::Headless.stub(:run, fake) do
      assert_equal "Fixing login. Done.", ClaudeCode::Summary.for(SESSION_ID)[:text]
      ClaudeCode::Summary.for(SESSION_ID)
    end

    assert_equal 1, calls.size
    assert_includes calls.first[0], "haiku"
    assert_includes calls.first[0], "--no-session-persistence"
    assert_includes calls.first[1], "you: fix login"
  end

  test "reports a failed claude run" do
    ClaudeCode::Headless.stub(:run, ->(*, **) { [ "Not logged in", Struct.new(:success?).new(false) ] }) do
      error = assert_raises(ClaudeCode::Summary::Error) { ClaudeCode::Summary.for(SESSION_ID) }
      assert_equal "Not logged in", error.message
    end
  end

  test "refuses unknown session ids" do
    assert_raises(ClaudeCode::Summary::Error) { ClaudeCode::Summary.for("../../etc/passwd") }
  end
end
