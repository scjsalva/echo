# Watches the scheduler from the web server only (not the job processes,
# consoles, runners or tests).
Rails.application.config.after_initialize do
  SyncWatchdog.start if defined?(Rails::Server) || $PROGRAM_NAME.include?("puma")
end
