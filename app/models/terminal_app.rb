# Opens a new terminal window running a command: Terminal on macOS, the
# desktop's terminal on Linux, Windows Terminal (or a command prompt) on Windows.
# The window stays open afterwards so you can read what happened.
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

  # A new tab in the front Terminal window, so a session you'll talk to sits with
  # your others. Opening the tab means pressing ⌘T through System Events, which
  # macOS allows once you've given the app running Echo Accessibility access.
  TAB_SCRIPT = [
    "on run argv",
    'if application "Terminal" is running then',
    'tell application "Terminal"',
    "if (count of windows) is 0 then",
    "do script (item 1 of argv)",
    "else",
    "activate",
    'tell application "System Events" to keystroke "t" using command down',
    "delay 0.3",
    "do script (item 1 of argv) in selected tab of front window",
    "end if",
    "activate",
    "end tell",
    "else",
    # Launching Terminal opens a window of its own, so the command goes in that one.
    'tell application "Terminal"',
    "activate",
    "do script (item 1 of argv) in window 1",
    "end tell",
    "end if",
    "end run"
  ].freeze

  # The first of these that's installed, with the flag that runs a command in it.
  LINUX_TERMINALS = [ %w[x-terminal-emulator -e], %w[gnome-terminal --], %w[konsole -e], %w[xfce4-terminal -x], %w[xterm -e] ].freeze

  def self.run(command)
    opened = case Platform.current
    when :mac then system("osascript", *SCRIPT.flat_map { [ "-e", it ] }, command, exception: false)
    when :linux then linux(command)
    when :windows then windows(command)
    end
    opened or raise Error, "Couldn't open a terminal. Run this in one yourself: #{command}"
  end

  # Opens a tab rather than a window where it can: Terminal on macOS. Without
  # Accessibility access the keystroke fails, so it falls back to a new window.
  def self.run_in_tab(command)
    return run(command) unless Platform.mac?

    system("osascript", *TAB_SCRIPT.flat_map { [ "-e", it ] }, command, exception: false) || run(command)
  end

  def self.linux(command)
    found = LINUX_TERMINALS.find { Platform.command?(it.first) } or return false
    terminal, flag = found
    Process.detach(spawn(terminal, flag, "sh", "-c", "#{command}; exec \"${SHELL:-sh}\"", out: File::NULL, err: File::NULL))
    true
  end

  # `start ""` gives the new window an empty title rather than taking the first word as one.
  def self.windows(command)
    args = Platform.command?("wt") ? [ "wt", "cmd", "/k", command ] : [ "cmd", "/c", "start", "", "cmd", "/k", command ]
    Process.detach(spawn(*args, out: File::NULL, err: File::NULL))
    true
  end

  private_class_method :linux, :windows
end
