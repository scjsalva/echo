require "test_helper"

class ClaudeCode::JobTest < ActiveSupport::TestCase
  include FakeClaudeHome

  setup { setup_claude_home }
  teardown { teardown_claude_home }

  test "turns a blocked background job into an agent that is waiting on the user" do
    write_json("jobs/abc/state.json", { name: "Review and approve", state: "blocked", detail: "Approval drafted", needs: "confirm posting the approval",
      cwd: File.join(Dir.home, "Projects/app"), updatedAt: 1.hour.ago.iso8601, createdAt: 2.hours.ago.iso8601 })

    job = ClaudeCode::Job.recent.sole

    assert_equal [ "job-abc", "background", "blocked", "Confirm posting the approval", "~/Projects/app" ], job.values_at(:id, :kind, :status, :needs, :cwd)
  end

  test "leaves out jobs that haven't changed in a week" do
    write_json("jobs/old/state.json", { name: "Old", state: "blocked", updatedAt: 10.days.ago.iso8601 })

    assert_empty ClaudeCode::Job.recent
  end
end
