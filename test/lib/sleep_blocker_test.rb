require "test_helper"

class SleepBlockerTest < ActiveSupport::TestCase
  test "each OS gets its own way of asking, all ending with Echo" do
    echo = Process.pid.to_s
    mac = RbConfig::CONFIG.stub(:[], ->(key) { key == "host_os" ? "darwin24" : nil }) { SleepBlocker.send(:command, "x") }
    assert_equal [ "caffeinate", "-i", "-w", echo ], mac

    windows = RbConfig::CONFIG.stub(:[], ->(key) { key == "host_os" ? "mingw32" : nil }) { SleepBlocker.send(:command, "x") }
    assert_equal "powershell", windows.first
    assert_includes windows.last, "SetThreadExecutionState(0x80000001)"
    assert_includes windows.last, "Get-Process -Id #{echo}"

    linux = SleepBlocker.stub(:installed?, true) do
      RbConfig::CONFIG.stub(:[], ->(key) { key == "host_os" ? "linux-gnu" : nil }) { SleepBlocker.send(:command, "2 agents working") }
    end
    assert_equal [ "systemd-inhibit", "--what=idle:sleep", "--who=Echo", "--why=2 agents working" ], linux.first(4)
    assert_includes linux.last, "kill -0 #{echo}"
  end
end
