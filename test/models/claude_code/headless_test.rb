require "test_helper"

class ClaudeCode::HeadlessTest < ActiveSupport::TestCase
  test "returns the output and records the run as ended" do
    output, status = ClaudeCode::Headless.run([ "cat" ], input: "hello", chdir: Dir.tmpdir, timeout: 5, purpose: "summary", ref: "acme/app#1")

    assert_equal "hello", output
    assert status.success?
    agent = SpawnedAgent.sole
    assert_equal [ "summary", "acme/app#1" ], [ agent.purpose, agent.ref ]
    assert agent.ended_at
  end

  test "ends the process and anything it started when it runs too long" do
    pid = nil
    assert_raises(ClaudeCode::Headless::Timeout) do
      ClaudeCode::Headless.run([ "sh", "-c", "sleep 30 & sleep 30" ], input: "", chdir: Dir.tmpdir, timeout: 0.3, purpose: "ai_review")
    ensure
      pid = SpawnedAgent.last.pid
    end

    assert_raises(Errno::ESRCH) { Process.kill(0, -pid) }
    assert SpawnedAgent.last.ended_at
  end

  test "tags a running Echo agent by pid" do
    SpawnedAgent.create!(pid: 4242, purpose: "ai_review", ref: "acme/app#3")

    assert_equal({ purpose: "ai_review", label: "AI review", ref: "acme/app#3" }, SpawnedAgent.tag_for(4242))
    assert_nil SpawnedAgent.tag_for(4243)
  end
end
