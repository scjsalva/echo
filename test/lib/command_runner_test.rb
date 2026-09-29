require "test_helper"

class CommandRunnerTest < ActiveSupport::TestCase
  test "returns what the command printed" do
    output, _, status = CommandRunner.capture("ruby", "-e", "print gets.strip.upcase", timeout: 10, stdin_data: "hi\n")
    assert status.success?
    assert_equal "HI", output
  end

  test "a run past its limit is ended, not left running" do
    started = Time.now
    assert_raises(CommandRunner::TimedOut) { CommandRunner.capture("ruby", "-e", "sleep 30", timeout: 0.5) }
    assert_operator Time.now - started, :<, 10
    assert_empty CommandRunner::RUNNING.keys
  end

  test "stop_all ends runs in progress, as after a wake" do
    run = Thread.new { CommandRunner.capture("ruby", "-e", "sleep 30", timeout: 60) rescue $! }
    sleep 0.1 until CommandRunner::RUNNING.size.positive?
    CommandRunner.stop_all

    assert_kind_of CommandRunner::Stopped, run.value
  end
end
