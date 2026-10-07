# Keeps Jira in sync every minute (config/recurring.yml), whether or not Echo is open.
class JiraSyncJob < ApplicationJob
  def perform
    return unless Jira::Connection.connected?

    SyncHealth.track("jira") do
      Jira::Sync.new.run
      Jira::BoardSync.new.run
    end
    Changes.bump
    Notifier.deliver_new
  end
end
