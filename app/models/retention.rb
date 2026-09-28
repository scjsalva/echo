# Keeps what Echo stores small: the job queue's history, and notifications,
# reviews and bookkeeping once they're old. Anything still waiting on you is
# kept, however old. Runs every hour (config/recurring.yml).
module Retention
  JOBS_FOR = 1.day
  FAILED_JOBS_FOR = 7.days
  NOTIFICATIONS_FOR = 30.days
  REVIEWS_FOR = 30.days
  ENDED_FOR = 1.day

  def self.run
    { finished_jobs: finished_jobs, schedule_records: schedule_records, failed_jobs: failed_jobs,
      notifications: notifications, deliveries: deliveries, reviews: reviews, spawned_agents: spawned_agents, session_signals: session_signals }
  end

  def self.finished_jobs
    queue do
      count = SolidQueue::Job.clearable(finished_before: JOBS_FOR.ago).count
      SolidQueue::Job.clear_finished_in_batches(finished_before: JOBS_FOR.ago)
      count
    end
  end

  def self.schedule_records = queue { SolidQueue::RecurringExecution.where(run_at: ...JOBS_FOR.ago).delete_all }

  def self.failed_jobs
    queue { SolidQueue::Job.where(id: SolidQueue::FailedExecution.where(created_at: ...FAILED_JOBS_FOR.ago).select(:job_id)).delete_all }
  end

  # The job queue's tables live in their own database, which tests don't have.
  def self.queue
    yield
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished
    0
  end

  # Old and done with: resolved, or never something that waited on you.
  def self.notifications
    old = NOTIFICATIONS_FOR.ago
    github = GithubNotification.where(occurred_at: ...old)
      .where.not(reason: WaitingItems::GITHUB_REASONS.keys).or(GithubNotification.where(occurred_at: ...old).where.not(resolved_at: nil))
    jira = JiraNotification.where(occurred_at: ...old)
      .where.not(kind: WaitingItems::JIRA_KINDS.keys).or(JiraNotification.where(occurred_at: ...old).where.not(resolved_at: nil))
    github.delete_all + jira.delete_all
  end

  # A sent notification is remembered so it isn't sent twice; once it's old and
  # no longer waiting, there's nothing left to send it again.
  def self.deliveries
    keep = Dashboard.current.waiting_items.select { it[:status] == "open" }.pluck(:delivery_key)
    Delivery.where(created_at: ...NOTIFICATIONS_FOR.ago).where.not(item_key: keep).delete_all
  end

  def self.reviews
    old = REVIEWS_FOR.ago
    stale = Review.where(status: "sent", sent_at: ...old).or(Review.where(status: "draft", updated_at: ...old).where.not(ai_status: %w[queued running]))
    stale.destroy_all.size
  end

  def self.spawned_agents = SpawnedAgent.where(ended_at: ...ENDED_FOR.ago).delete_all

  def self.session_signals
    live = ClaudeCode::Session.live.map(&:id)
    SessionSignal.where(updated_at: ...ENDED_FOR.ago).where.not(session_id: live).delete_all
  end

  private_class_method :queue, :finished_jobs, :schedule_records, :failed_jobs, :notifications, :deliveries, :reviews, :spawned_agents, :session_signals
end
