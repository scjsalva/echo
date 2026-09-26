# Brings installed copies of Echo's Claude Code skills up to date when Echo starts.
Rails.application.config.after_initialize do
  next if Rails.env.test? || defined?(Rails::Console) || !ActiveRecord::Base.connection.table_exists?("settings")

  ClaudeCode::Integration.refresh
rescue ActiveRecord::ActiveRecordError, Errno::ENOENT, Errno::EACCES
  nil
end
