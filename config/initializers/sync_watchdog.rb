require "command_runner"
require "sleep_blocker"

# Watches the scheduler from the web server only (not the job processes,
# consoles, runners or tests).
Rails.application.config.after_initialize do
  # Kept here, not in SyncWatchdog, so code reloads don't reset it.
  Rails.application.config.x.booted_at = Time.current
  SyncWatchdog.start if defined?(Rails::Server) || $PROGRAM_NAME.include?("puma")
end
