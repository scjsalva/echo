# Opens a new Terminal.app window running a command.
module TerminalApp
  class Error < StandardError; end

  # The command is passed as an argument rather than interpolated into the
  # script, so nothing in it can break out of the AppleScript string.
  SCRIPT = [
    "on run argv",
    'tell application "Terminal"',
    "activate",
    "do script (item 1 of argv)",
    "end tell",
    "end run"
  ].freeze

  def self.run(command)
    system("osascript", *SCRIPT.flat_map { [ "-e", it ] }, command, exception: false) or raise Error, "Couldn't open Terminal"
  end
end
