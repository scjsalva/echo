# How Echo's background syncs are doing, for Settings → Connections → Health:
# when each last ran and succeeded, and its last error. The scheduler that
# starts them every minute is watched too (see SyncWatchdog).
module SyncHealth
  SOURCES = {
    "github" => { label: "GitHub sync", job: "GithubSyncJob", every: 1.minute },
    "jira" => { label: "Jira sync", job: "JiraSyncJob", every: 1.minute },
    "notify" => { label: "Notification check", job: "NotifyJob", every: 30.seconds }
  }.freeze
  # A sync that hasn't succeeded for this many runs in a row is failing.
  FAILING_AFTER = 3

  def self.key(source) = "sync_health_#{source}"
  def self.state(source) = Setting[key(source)] ? JSON.parse(Setting[key(source)]) : {}

  # Wraps one run: records it started, then how it ended.
  mattr_accessor :lock_dir, default: Rails.root.join("tmp")
  # Queued but not started for this long, while the scheduler runs, means something is holding it back.
  NOT_STARTING_AFTER = 5.minutes
  # A run takes well under a minute; one "running" longer was cut off (a restart,
  # the computer sleeping) before it could record that it ended.
  RUNNING_AT_MOST = 5.minutes

  # Wraps one run: one at a time per sync, then records how it ended. The lock
  # is a file lock, which the system drops the moment its process dies, so a
  # worker that crashes or is replaced (e.g. after the computer sleeps) can't leave
  # the next runs waiting behind it.
  def self.track(source)
    File.open(lock_dir.join("sync-#{source}.lock"), File::RDWR | File::CREAT) do |lock|
      unless lock.flock(File::LOCK_EX | File::LOCK_NB)
        record(source, "last_skipped_at" => Time.current.iso8601)
        return
      end

      record(source, "last_attempt_at" => Time.current.iso8601, "running_since" => Time.current.iso8601)
      begin
        result = yield
        record(source, "last_success_at" => Time.current.iso8601, "failures" => 0, "running_since" => nil)
        result
      rescue StandardError => e
        failures = state(source)["failures"].to_i + 1
        record(source, "last_error" => e.message.truncate(300), "last_error_at" => Time.current.iso8601, "failures" => failures, "running_since" => nil)
        raise
      end
    end
  end

  def self.record(source, changes) = Setting[key(source)] = state(source).merge(changes).to_json

  # Nil when there's no job queue to ask, e.g. in tests.
  def self.last_scheduled_at
    SolidQueue::RecurringExecution.maximum(:run_at)
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished
    nil
  end

  # A sync for something that isn't connected doesn't run, so it isn't worth showing as a problem.
  def self.connected?(source)
    case source
    when "github" then Github::Connection.connected?
    when "jira" then Jira::Connection.connected?
    else true
    end
  rescue StandardError
    false
  end

  def self.props
    scheduled = last_scheduled_at
    {
      scheduler: { last_run_at: scheduled, stalled: SyncWatchdog.stalled?(scheduled), covering_since: Setting[SyncWatchdog::COVERING],
                   booted_at: Rails.application.config.x.booted_at, restarted_at: Setting[SyncWatchdog::RESTARTED] },
      syncs: SOURCES.map do |source, info|
        s = state(source)
        attempted = s["last_attempt_at"] && Time.zone.parse(s["last_attempt_at"])
        not_starting = !SyncWatchdog.stalled?(scheduled) && connected?(source) && (attempted.nil? || attempted < NOT_STARTING_AFTER.ago)
        status = if s["failures"].to_i >= FAILING_AFTER then "failing"
        elsif not_starting then "not_starting"
        elsif s["last_success_at"].nil? then "unknown"
        elsif Time.zone.parse(s["last_success_at"]) < (info[:every] * 5).ago then "stale"
        else "ok"
        end
        { source:, label: info[:label], status:, connected: connected?(source), last_success_at: s["last_success_at"], last_attempt_at: s["last_attempt_at"],
          last_error: s["last_error"], last_error_at: s["last_error_at"], failures: s["failures"].to_i,
          running_since: (s["running_since"] if s["running_since"] && Time.zone.parse(s["running_since"]) > RUNNING_AT_MOST.ago),
          last_skipped_at: s["last_skipped_at"] }
      end
    }
  end
end
