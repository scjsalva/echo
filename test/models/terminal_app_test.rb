require "test_helper"

class TerminalAppTest < ActiveSupport::TestCase
  test "on Linux, opens the first terminal that's installed and keeps it open afterwards" do
    spawned = nil
    Platform.stub(:current, :linux) do
      Platform.stub(:command?, ->(name) { name == "konsole" }) do
        TerminalApp.stub(:spawn, ->(*args, **) { spawned = args; 0 }) do
          Process.stub(:detach, nil) { TerminalApp.run("gh auth login") }
        end
      end
    end
    assert_equal [ "konsole", "-e", "sh", "-c", 'gh auth login; exec "${SHELL:-sh}"' ], spawned
  end

  test "on Windows, uses Windows Terminal when it's there, else a command prompt" do
    spawned = []
    Platform.stub(:current, :windows) do
      TerminalApp.stub(:spawn, ->(*args, **) { spawned << args; 0 }) do
        Process.stub(:detach, nil) do
          Platform.stub(:command?, true) { TerminalApp.run("gh auth login") }
          Platform.stub(:command?, false) { TerminalApp.run("gh auth login") }
        end
      end
    end
    assert_equal [ [ "wt", "cmd", "/k", "gh auth login" ], [ "cmd", "/c", "start", "", "cmd", "/k", "gh auth login" ] ], spawned
  end

  test "on macOS, opens a tab in Terminal, or a window when the tab can't be opened" do
    calls = []
    Platform.stub(:current, :mac) do
      TerminalApp.stub(:system, ->(*args, **) { calls << args.last; calls.size > 1 }) { TerminalApp.run_in_tab("claude") }
    end
    assert_equal [ "claude", "claude" ], calls, "tab first, then a window"
  end

  test "says what to run when no terminal can be opened" do
    error = Platform.stub(:current, :linux) do
      Platform.stub(:command?, false) { assert_raises(TerminalApp::Error) { TerminalApp.run("gh auth login") } }
    end
    assert_match "Run this in one yourself: gh auth login", error.message
  end
end
