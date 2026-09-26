require "open3"

# Keeps the syncs going if Solid Queue's scheduler stops starting them (it once
# hung after its worker was restarted). Runs in the web server: when the
# scheduler has been quiet for a few minutes it starts the syncs itself, and if
# it stays quiet it restarts the scheduler so it can pick up again.
module SyncWatchdog
  CHECK_EVERY = 60
  STALLED_AFTER = 3.minutes
  RESTART_AFTER = 5.minutes
  COVERING = "sync_watchdog_covering_since".freeze
  JOBS = [ GithubSyncJob, JiraSyncJob, NotifyJob ].freeze

  def self.start
    Thread.new do
      loop do
        sleep CHECK_EVERY
        Rails.application.executor.wrap { check }
      rescue StandardError => e
        Rails.logger.warn("Sync watchdog: #{e.class}: #{e.message}")
      end
    end
  end

  def self.stalled?(last = SyncHealth.last_scheduled_at) = last.nil? || last < STALLED_AFTER.ago

  def self.check
    last = SyncHealth.last_scheduled_at
    unless stalled?(last)
      Setting.find_by(key: COVERING)&.destroy
      return
    end

    Setting[COVERING] ||= Time.current.iso8601
    JOBS.each(&:perform_later)
    restart_scheduler if last.nil? || last < RESTART_AFTER.ago
  end

  # Only Echo's own scheduler: the one its Solid Queue supervisor started.
  def self.restart_scheduler
    supervisor = SolidQueue::Process.where(kind: "Supervisor(fork)").pluck(:pid).find { alive?(it) } or return
    output, = Open3.capture2("pgrep", "-P", supervisor.to_s, "-f", "solid-queue-scheduler")
    output.split.map(&:to_i).each do |pid|
      Rails.logger.warn("Sync watchdog: restarting the stuck scheduler (pid #{pid})")
      Process.kill("KILL", pid)
    end
  end

  def self.alive?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH, Errno::EPERM
    false
  end

  private_class_method :restart_scheduler, :alive?
end
