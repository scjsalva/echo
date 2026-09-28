# Keeps GitHub in sync every minute (config/recurring.yml), whether or not Echo is open.
class GithubSyncJob < ApplicationJob
  def perform
    return unless Github::Connection.connected?

    SyncHealth.track("github") { Github::Sync.new.run }
    Changes.bump
    Notifier.deliver_new
  end
end
