# Summarises the tickets Find me work needs, in the background.
class FindWorkJob < ApplicationJob
  def perform(keys = nil)
    Jira::FindWork.run(keys)
  rescue Jira::FindWork::Error, Jira::Cli::Error => e
    Rails.cache.write(Jira::FindWork::LAST_ERROR, e.message, expires_in: 1.hour)
  end
end
