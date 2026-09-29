require "open3"

# Runs a command-line tool (gh, acli) with a time limit that ends the process
# too, not just the wait for it. It keeps track of what's running so that,
# after the computer wakes from sleep, runs whose network connections died
# while it slept can be ended at once instead of hanging until their limit.
# Loaded once (not reloaded with Echo's code) so that record survives reloads.
module CommandRunner
  class TimedOut < StandardError; end
  class Stopped < StandardError; end

  RUNNING = Concurrent::Map.new

  # Returns [stdout, stderr, status], like Open3.capture3.
  def self.capture(*command, timeout:, stdin_data: nil)
    Open3.popen3(*command) do |stdin, out, err, wait|
      RUNNING[wait.pid] = :running
      output = Thread.new { out.read }
      error = Thread.new { err.read }
      begin
        stdin.write(stdin_data.to_s)
      rescue Errno::EPIPE
        nil # It finished without reading its input.
      end
      stdin.close

      unless wait.join(timeout)
        stop(wait.pid)
        wait.join
        raise TimedOut
      end
      raise Stopped if RUNNING[wait.pid] == :stopped

      [ output.value, error.value, wait.value ]
    ensure
      RUNNING.delete(wait.pid)
    end
  end

  # Ends every run in progress, e.g. after waking from sleep.
  def self.stop_all
    RUNNING.each_key do |pid|
      RUNNING[pid] = :stopped
      stop(pid)
    end
  end

  # Windows has no TERM signal; KILL ends the process there.
  def self.stop(pid)
    Process.kill(Gem.win_platform? ? "KILL" : "TERM", pid)
  rescue Errno::ESRCH, Errno::EPERM, Errno::ECHILD
    nil
  end
end
