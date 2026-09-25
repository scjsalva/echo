require "test_helper"

class SessionSignalTest < ActiveSupport::TestCase
  def record(name, **fields) = SessionSignal.record({ "session_id" => "s1", "hook_event_name" => name }.merge(fields.stringify_keys))
  def needs = SessionSignal.find_by(session_id: "s1")&.needs

  test "a permission request blocks the session with what it wants to do" do
    record("PermissionRequest", tool_name: "Bash", tool_input: { "command" => "git push origin main" })

    assert_equal "Allow Bash(git push origin main)", needs
  end

  test "a subagent's request blocks its parent session and says which subagent asked" do
    record("PermissionRequest", tool_name: "Bash", tool_input: { "command" => "rm -rf tmp/cache" }, agent_id: "a9", agent_type: "Explore")

    assert_equal "Allow Bash(rm -rf tmp/cache) · Explore subagent", needs
  end

  test "a question asked through permissions reads as a question" do
    record("PermissionRequest", tool_name: "AskUserQuestion", tool_input: { "questions" => [] })

    assert_equal "Claude is asking you a question", needs
  end

  test "the permission notification doesn't replace the detailed request" do
    record("PermissionRequest", tool_name: "Edit", tool_input: { "file_path" => "/app/x.rb" })
    record("Notification", notification_type: "permission_prompt", message: "Claude needs your permission to use Edit")

    assert_equal "Allow Edit(/app/x.rb)", needs
  end

  test "a question blocks it too, and idle reminders don't" do
    record("Notification", notification_type: "idle_prompt", message: "Claude is waiting for your input")
    assert_nil needs

    record("Notification", notification_type: "elicitation_dialog")
    assert_equal "Claude is asking you a question", needs
  end

  test "carrying on clears it" do
    %w[PostToolUse UserPromptSubmit Stop SessionEnd].each do |event|
      record("PermissionRequest", tool_name: "Bash")
      record(event)

      assert_nil needs, "#{event} should clear the block"
    end
  end

  test "ignores events without a session" do
    assert_not SessionSignal.record({ "hook_event_name" => "Stop" })
  end
end
