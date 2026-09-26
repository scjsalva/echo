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
  def self.track(source)
    record(source, "last_attempt_at" => Time.current.iso8601)
    result = yield
    record(source, "last_success_at" => Time.current.iso8601, "failures" => 0)
    result
  rescue StandardError => e
    failures = state(source)["failures"].to_i + 1
    record(source, "last_error" => e.message.truncate(300), "last_error_at" => Time.current.iso8601, "failures" => failures)
    raise
  end

  def self.record(source, changes) = Setting[key(source)] = state(source).merge(changes).to_json

  # Nil when there's no job queue to ask, e.g. in tests.
  def self.last_scheduled_at
    SolidQueue::RecurringExecution.maximum(:run_at)
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished
    nil
  end

  def self.props
    scheduled = last_scheduled_at
    {
      scheduler: { last_run_at: scheduled, stalled: SyncWatchdog.stalled?(scheduled), covering_since: Setting[SyncWatchdog::COVERING] },
      syncs: SOURCES.map do |source, info|
        s = state(source)
        status = if s["failures"].to_i >= FAILING_AFTER then "failing"
        elsif s["last_success_at"].nil? then "unknown"
        elsif Time.zone.parse(s["last_success_at"]) < (info[:every] * 5).ago then "stale"
        else "ok"
        end
        { source:, label: info[:label], status:, last_success_at: s["last_success_at"], last_attempt_at: s["last_attempt_at"],
          last_error: s["last_error"], last_error_at: s["last_error_at"], failures: s["failures"].to_i }
      end
    }
  end
end
