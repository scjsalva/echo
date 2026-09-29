# Asks the OS not to go to sleep when idle, the way video players and backups
# do. The display still turns off and the screen still locks on their usual
# timers; only system sleep waits (and closing a laptop's lid still sleeps it).
# A small helper process holds the request and ends by itself if Echo does,
# so nothing is ever left holding it. Loaded once, like CommandRunner, so
# code reloads don't lose track of the helper.
module SleepBlocker
  PIDFILE = File.expand_path("../tmp/pids/sleep-blocker.pid", __dir__)
  MUTEX = Mutex.new

  WINDOWS = <<~POWERSHELL.freeze
    Add-Type -Name Power -Namespace Echo -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags);'
    [Echo.Power]::SetThreadExecutionState(0x80000001) | Out-Null
    while (Get-Process -Id ECHO_PID -ErrorAction SilentlyContinue) { Start-Sleep -Seconds 5 }
  POWERSHELL

  def self.available? = !command("").nil?

  def self.held? = MUTEX.synchronize { running_pid.present? }

  def self.hold(reason)
    MUTEX.synchronize do
      next true if running_pid

      command = command(reason) or next false
      pid = Process.spawn(*command, out: File::NULL, err: File::NULL)
      Process.detach(pid)
      FileUtils.mkdir_p(File.dirname(PIDFILE))
      File.write(PIDFILE, pid.to_s)
      true
    end
  rescue SystemCallError
    false
  end

  def self.release
    MUTEX.synchronize do
      pid = running_pid or next
      Process.kill(Gem.win_platform? ? "KILL" : "TERM", pid)
    rescue SystemCallError
      nil
    ensure
      FileUtils.rm_f(PIDFILE)
    end
  end

  # The helper from the pidfile, still running. Echo restarts in place (same
  # pid), so a helper started before a restart is picked up, not doubled.
  def self.running_pid
    pid = File.read(PIDFILE).to_i
    pid if pid.positive? && Process.kill(0, pid)
  rescue SystemCallError
    nil
  end

  def self.command(reason)
    echo = Process.pid.to_s
    case RbConfig::CONFIG["host_os"]
    when /darwin/ then [ "caffeinate", "-i", "-w", echo ]
    when /linux/
      [ "systemd-inhibit", "--what=idle:sleep", "--who=Echo", "--why=#{reason}", "--mode=block",
        "sh", "-c", "while kill -0 #{echo} 2>/dev/null; do sleep 5; done" ] if installed?("systemd-inhibit")
    when /mswin|mingw|cygwin/ then [ "powershell", "-NoProfile", "-WindowStyle", "Hidden", "-Command", WINDOWS.gsub("ECHO_PID", echo) ]
    end
  end

  def self.installed?(name) = system("which", name, out: File::NULL, err: File::NULL, exception: false)

  private_class_method :running_pid, :command, :installed?
end
