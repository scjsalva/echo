require "test_helper"

class KeepAwakeTest < ActiveSupport::TestCase
  Session = Struct.new(:working?)

  setup { @held = nil }

  test "is off unless turned on" do
    assert_equal "off", KeepAwake.mode
    with_sessions([ Session.new(true) ]) { update }
    assert_equal :released, @held
  end

  test "while agents are working: holds while one is busy, and a while after" do
    KeepAwake.stub(:update, nil) { KeepAwake.mode = "agents" }
    with_cache do
      with_sessions([ Session.new(true), Session.new(false) ]) { update }
      assert_equal [ :held, "1 agent working" ], @held

      with_sessions([ Session.new(false) ]) { update }
      assert_equal [ :held, "An agent was working a few minutes ago" ], @held

      travel(KeepAwake::GRACE + 1.minute) { with_sessions([ Session.new(false) ]) { update } }
      assert_equal :released, @held
    end
  end

  test "during working hours: holds only inside them" do
    KeepAwake.stub(:update, nil) { KeepAwake.mode = "working_hours" }
    WorkingHours.stub(:within?, true) { update }
    assert_equal [ :held, "During your working hours" ], @held
    WorkingHours.stub(:within?, false) { update }
    assert_equal :released, @held
  end

  test "refuses modes it doesn't know" do
    assert_raises(ArgumentError) { KeepAwake.mode = "always" }
  end

  private

  def update
    SleepBlocker.stub(:hold, ->(reason) { @held = [ :held, reason ] }) do
      SleepBlocker.stub(:release, -> { @held = :released }) { KeepAwake.update }
    end
  end

  def with_sessions(sessions, &) = ClaudeCode::Session.stub(:live, sessions, &)
  def with_cache(&) = Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new, &)
end
