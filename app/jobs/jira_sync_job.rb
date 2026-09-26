# Keeps Jira in sync every minute (config/recurring.yml), whether or not Echo is open.
class JiraSyncJob < ApplicationJob
  limits_concurrency to: 1, key: "jira_sync", duration: 10.minutes

  def perform
    return unless Jira::Connection.connected?

    SyncHealth.track("jira") { Jira::Sync.new.run }
    Changes.bump
    Notifier.deliver_new
  end
end
