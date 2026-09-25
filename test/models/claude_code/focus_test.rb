require "test_helper"

class ClaudeCode::FocusTest < ActiveSupport::TestCase
  include FakeClaudeHome

  Status = Struct.new(:success?)

  setup { setup_claude_home }
  teardown { teardown_claude_home }

  test "finds the Terminal tab by the session's tty and brings it forward" do
    osascript = nil
    capture2e = ->(*args) { osascript = args; [ "found\n", Status.new(true) ] }

    with_process_tree(tty: "ttys005", host: "Terminal") do
      Open3.stub(:capture2e, capture2e) { ClaudeCode::Focus.focus(SESSION_ID) }
    end

    assert_equal "osascript", osascript.first
    assert_includes osascript[2], 'tell application "Terminal"'
    assert_equal "/dev/ttys005", osascript.last
  end

  test "types a line into the session's tab" do
    osascript = nil

    with_process_tree(tty: "ttys005", host: "Terminal") do
      Open3.stub(:capture2e, ->(*args) { osascript = args; [ "found\n", Status.new(true) ] }) do
        ClaudeCode::Focus.type(SESSION_ID, "/rename Payments work")
      end
    end

    assert_includes osascript[2], "do script (item 2 of argv) in t"
    assert_equal [ "/dev/ttys005", "/rename Payments work" ], osascript.last(2)
  end

  test "explains when the tab can't be found" do
    with_process_tree(tty: "ttys005", host: "Terminal") do
      Open3.stub(:capture2e, ->(*) { [ "missing\n", Status.new(true) ] }) do
        error = assert_raises(ClaudeCode::Focus::Error) { ClaudeCode::Focus.focus(SESSION_ID) }
        assert_equal "Couldn't find the Terminal tab for this session", error.message
      end
    end
  end

  test "says up front when a session has no terminal to show" do
    Open3.stub(:capture2, ->(*) { [ "??\n", Status.new(true) ] }) do
      assert_equal "This session isn't running in a terminal window", ClaudeCode::Focus.unavailable_reason(Process.pid)
    end
  end

  test "refuses tmux and unknown hosts with a reason" do
    with_process_tree(tty: "ttys005", host: "tmux") do
      error = assert_raises(ClaudeCode::Focus::Error) { ClaudeCode::Focus.focus(SESSION_ID) }
      assert_match "tmux", error.message
    end
  end

  test "refuses sessions that aren't running" do
    error = assert_raises(ClaudeCode::Focus::Error) { ClaudeCode::Focus.focus("99999999-8888-7777-6666-555555555555") }
    assert_equal "This session isn't running", error.message
  end

  private

  # Fakes `ps`: the session's tty, one shell parent, then the host app.
  def with_process_tree(tty:, host:, &)
    shell_pid = 101
    host_pid = 100
    ps = lambda do |_ps, _o, field, _p, pid|
      value = case [ field, pid.to_i ]
      in [ "tty=", _ ] then tty
      in [ "ppid=", ^shell_pid ] then host_pid
      in [ "ppid=", ^host_pid ] then 1
      in [ "ppid=", _ ] then shell_pid
      in [ "comm=", ^host_pid ] then "/Applications/#{host}.app/Contents/MacOS/#{host}"
      in [ "comm=", _ ] then "-zsh"
      end
      [ "#{value}\n", Status.new(true) ]
    end
    Open3.stub(:capture2, ps, &)
  end
end
