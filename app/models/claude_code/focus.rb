require "open3"

# Brings the terminal tab a live session runs in to the front. Tabs are matched
# by the session process's tty, which Terminal, iTerm2 and tmux all expose.
# Terminal and iTerm2 are driven through AppleScript, so macOS only; tmux works
# wherever tmux does (macOS, Linux). Other terminals offer no way in.
module ClaudeCode::Focus
  class Error < StandardError; end

  SCRIPTS = {
    "Terminal" => <<~APPLESCRIPT,
      on run argv
        tell application "Terminal"
          repeat with w in windows
            repeat with t in tabs of w
              if tty of t is (item 1 of argv) then
                set miniaturized of w to false
                set selected of t to true
                set index of w to 1
                activate
                return "found"
              end if
            end repeat
          end repeat
        end tell
        return "missing"
      end run
    APPLESCRIPT
    "iTerm2" => <<~APPLESCRIPT
      on run argv
        tell application "iTerm2"
          repeat with w in windows
            repeat with t in tabs of w
              repeat with s in sessions of t
                if tty of s is (item 1 of argv) then
                  select w
                  select t
                  select s
                  activate
                  return "found"
                end if
              end repeat
            end repeat
          end repeat
        end tell
        return "missing"
      end run
    APPLESCRIPT
  }.freeze

  # Process names as `ps` reports them, mapped to the app that owns the tab.
  HOSTS = { "Terminal" => "Terminal", "iTerm2" => "iTerm2", "tmux" => "tmux" }.freeze

  # Types text into a session's tab and presses return, as if you had.
  TYPE_SCRIPTS = {
    "Terminal" => <<~APPLESCRIPT,
      on run argv
        tell application "Terminal"
          repeat with w in windows
            repeat with t in tabs of w
              if tty of t is (item 1 of argv) then
                do script (item 2 of argv) in t
                return "found"
              end if
            end repeat
          end repeat
        end tell
        return "missing"
      end run
    APPLESCRIPT
    "iTerm2" => <<~APPLESCRIPT
      on run argv
        tell application "iTerm2"
          repeat with w in windows
            repeat with t in tabs of w
              repeat with s in sessions of t
                if tty of s is (item 1 of argv) then
                  tell s to write text (item 2 of argv)
                  return "found"
                end if
              end repeat
            end repeat
          end repeat
        end tell
        return "missing"
      end run
    APPLESCRIPT
  }.freeze

  def self.focus(session_id) = run_in_tab(session_id, SCRIPTS)

  # Sends `text` to the session as a line of input, e.g. "/rename Payments work".
  def self.type(session_id, text) = run_in_tab(session_id, TYPE_SCRIPTS, text)

  def self.run_in_tab(session_id, scripts, *extra)
    session = ClaudeCode::Session.find(session_id) or raise Error, "This session isn't running"
    target = target(session.pid)
    raise Error, target[:unavailable] if target[:unavailable]

    host = target[:host]
    return tmux(target[:pane], scripts.equal?(SCRIPTS) ? :focus : :type, *extra) if host == "tmux"

    output, status = Open3.capture2e("osascript", "-e", scripts.fetch(host), "/dev/#{target[:tty]}", *extra)
    raise Error, "Couldn't reach #{host}: #{output.strip.truncate(200)}" unless status.success?
    raise Error, "Couldn't find the #{host} tab for this session" unless output.strip == "found"
  end

  # Why a session's terminal can't be brought forward, or nil when it can. A
  # process keeps its terminal for life, so this is worked out once per process.
  def self.unavailable_reason(pid) = Rails.cache.fetch([ "focus-target", pid ], expires_in: 1.hour) { target(pid) }[:unavailable]

  def self.target(pid)
    return { unavailable: "Windows gives Echo no way to bring a terminal tab forward" } if Platform.windows?

    tty = ps("tty", pid)
    return { unavailable: "This session isn't running in a terminal window" } if tty.blank? || tty == "??"

    host = host_app(pid)
    if host == "tmux"
      pane = tmux_pane(tty) or return { unavailable: "Couldn't find this session's tmux pane" }
      return { tty:, host:, pane: }
    end
    return { unavailable: "Echo can bring Terminal, iTerm2 and tmux tabs forward, not #{host || 'this app'}" } if Platform.mac? && !SCRIPTS.key?(host)
    return { unavailable: "Outside macOS, Echo can only bring tmux panes forward. Run Claude Code in tmux to use this" } unless SCRIPTS.key?(host) && Platform.mac?

    { tty:, host: }
  end

  def self.tmux_pane(tty)
    output, status = Open3.capture2("tmux", "list-panes", "-a", "-F", "\#{pane_tty} \#{pane_id}")
    return unless status.success?

    output.lines.map(&:split).find { |pane_tty, _| pane_tty == "/dev/#{tty}" }&.last
  rescue SystemCallError
    nil
  end

  # Focus switches your tmux client to the pane; typing sends the text, then return.
  def self.tmux(pane, action, text = nil)
    commands = if action == :focus
      [ [ "switch-client", "-t", pane ], [ "select-window", "-t", pane ], [ "select-pane", "-t", pane ] ]
    else
      [ [ "send-keys", "-t", pane, "-l", text ], [ "send-keys", "-t", pane, "Enter" ] ]
    end
    # switch-client fails when no client is attached; the rest still apply.
    results = commands.map { |args| Open3.capture2e("tmux", *args) }
    raise Error, "Couldn't reach tmux: #{results.last.first.strip.truncate(200)}" unless results.last.last.success?
  end

  # Walks up the process tree to the first process that owns terminal tabs.
  def self.host_app(pid)
    8.times do
      pid = ps("ppid", pid).to_i
      return if pid <= 1

      name = File.basename(ps("comm", pid))
      return HOSTS[name] if HOSTS.key?(name)
    end
    nil
  end

  def self.ps(field, pid)
    output, status = Open3.capture2("ps", "-o", "#{field}=", "-p", pid.to_s)
    status.success? ? output.strip : ""
  end

  private_class_method :run_in_tab, :target, :host_app, :ps, :tmux_pane, :tmux
end
