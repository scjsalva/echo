# Keeps the syncs going if Solid Queue's scheduler stops starting them. Runs in
# the web server: when the scheduler has been quiet for a few minutes it starts
# the syncs itself, and it clears out jobs left behind by a worker that died.
# When no sync has even started for half an hour (the Mac slept, or the queue
# is stuck) it restarts Echo, so everything starts fresh without you.
module SyncWatchdog
  CHECK_EVERY = 60
  STALLED_AFTER = 3.minutes
  RESTART_AFTER = 30.minutes
  COVERING = "sync_watchdog_covering_since".freeze
  RESTARTED = "sync_watchdog_restarted_at".freeze
  JOBS = [ GithubSyncJob, JiraSyncJob, NotifyJob ].freeze
  mattr_accessor :restart_file, default: Rails.root.join("tmp/restart.txt")

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
    return restart if restart?

    release_orphans
    last = SyncHealth.last_scheduled_at
    unless stalled?(last)
      Setting.find_by(key: COVERING)&.destroy
      return
    end

    Setting[COVERING] ||= Time.current.iso8601
    JOBS.each(&:perform_later)
  end

  # Up long enough to have synced, yet nothing has started since before the
  # pause, and not already restarted for it. Puma's tmp_restart plugin does the
  # restart; the job queue comes back with it.
  def self.restart?
    last = SyncHealth::SOURCES.keys.filter_map { SyncHealth.state(it)["last_attempt_at"] }.max&.then { Time.zone.parse(it) }
    restarted = Setting[RESTARTED]&.then { Time.zone.parse(it) }
    Rails.application.config.x.booted_at < RESTART_AFTER.ago && last.present? && last < RESTART_AFTER.ago && (restarted.nil? || restarted < last)
  end

  def self.restart
    Rails.logger.warn("Sync watchdog: no sync has started for #{RESTART_AFTER.inspect}; restarting Echo")
    Setting[RESTARTED] = Time.current.iso8601
    FileUtils.touch(restart_file)
  end

  # Jobs claimed by a worker that has since died (e.g. replaced after the Mac
  # slept) would otherwise sit "in progress" for good.
  def self.release_orphans
    orphans = SolidQueue::ClaimedExecution.orphaned
    return if orphans.none?

    Rails.logger.warn("Sync watchdog: failing #{orphans.count} job(s) left by a worker that died")
    orphans.fail_all_with(SolidQueue::Processes::ProcessMissingError.new)
  end

  private_class_method :release_orphans, :restart
end
