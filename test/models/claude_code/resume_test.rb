require "test_helper"

class ClaudeCode::ResumeTest < ActiveSupport::TestCase
  include FakeClaudeHome

  ENDED_ID = "99999999-8888-7777-6666-555555555555".freeze

  setup { setup_claude_home }
  teardown { teardown_claude_home }

  test "builds a shell-safe resume command" do
    assert_equal 'cd /tmp/a\ b\;\ rm && claude --resume ' + ENDED_ID, ClaudeCode::Resume.command(ENDED_ID, "/tmp/a b; rm")
    assert_equal "claude --resume #{ENDED_ID}", ClaudeCode::Resume.command(ENDED_ID, nil)
  end

  test "opens Terminal with the command passed as an argument" do
    append_transcript(human("go").merge(cwd: "/tmp/app"), path: transcript_path(ENDED_ID))
    calls = []

    TerminalApp.stub(:system, ->(*args, **) { calls << args; true }) do
      ClaudeCode::Resume.open_in_terminal(ENDED_ID)
    end

    assert_equal "osascript", calls.sole.first
    assert_equal "cd /tmp/app && claude --resume #{ENDED_ID}", calls.sole.last
  end

  test "won't resume a session that is still running" do
    append_transcript(human("go"))

    error = assert_raises(ClaudeCode::Resume::Error) { ClaudeCode::Resume.open_in_terminal(SESSION_ID) }
    assert_equal "This session is still running", error.message
  end
end
