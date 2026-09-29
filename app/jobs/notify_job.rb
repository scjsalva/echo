# Sends desktop notifications for anything new. Runs after hook events and syncs,
# and every 30 seconds as a catch-all (config/recurring.yml).
class NotifyJob < ApplicationJob
  def perform = SyncHealth.track("notify") { Notifier.deliver_new }
end
