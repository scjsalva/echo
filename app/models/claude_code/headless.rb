require "open3"

# Runs `claude -p` for Echo's own work. Each run gets its own process group so
# a timeout or error ends it and anything it started, instead of leaving an
# idle agent behind.
module ClaudeCode::Headless
  class Timeout < StandardError; end

  GRACE = 5

  def self.run(command, input:, chdir:, timeout:, purpose:, ref: nil)
    reap
    group = Platform.windows? ? { new_pgroup: true } : { pgroup: true }
    Open3.popen2e(*command, chdir: chdir.to_s, **group) do |stdin, out, wait|
      agent = SpawnedAgent.create!(pid: wait.pid, purpose:, ref:)
      reader = Thread.new { out.read }
      begin
        stdin.write(input.to_s)
        stdin.close
        raise Timeout, "Claude took longer than #{timeout.inspect}" unless wait.join(timeout)

        [ reader.value, wait.value ]
      ensure
        stop(wait.pid) if wait.alive?
        agent.update!(ended_at: Time.current)
      end
    end
  end

  # Ends a run's whole process group: politely, then for sure. Windows has no
  # process groups to signal, so there taskkill ends the process and its children.
  def self.stop(pid)
    return system("taskkill", "/T", "/F", "/PID", pid.to_s, out: File::NULL, err: File::NULL, exception: false) if Platform.windows?

    Process.kill("TERM", -pid)
    (GRACE * 10).times { Process.kill(0, pid) && sleep(0.1) }
    Process.kill("KILL", -pid)
  rescue Errno::ESRCH, Errno::EPERM
    nil
  end

  # Runs left over from a crash or restart, which nothing is waiting on any more.
  def self.reap
    SpawnedAgent.running.where(created_at: ...1.hour.ago).find_each do |agent|
      stop(agent.pid) if claude?(agent.pid)
      agent.update!(ended_at: Time.current)
    end
  end

  # Pids get reused, so only stop a process that is still a claude run.
  def self.claude?(pid)
    if Platform.windows?
      output, status = Open3.capture2("tasklist", "/FI", "PID eq #{pid}", "/FO", "CSV", "/NH")
      return status.success? && output.match?(/\A"claude(\.exe)?"/i)
    end

    output, status = Open3.capture2("ps", "-o", "comm=", "-p", pid.to_s)
    status.success? && File.basename(output.strip) == "claude"
  end

  private_class_method :reap, :claude?
end
