# Whether acli is logged in to Jira. Checked at most every 30 seconds.
module Jira::Connection
  LOGIN_COMMAND = "acli jira auth login --web".freeze
  CACHE_KEY = "jira-connection".freeze

  def self.status
    Rails.cache.fetch(CACHE_KEY, expires_in: 30.seconds) do
      output = Jira::Cli.run("auth", "status")
      field = ->(name) { output[/^\s*#{name}:\s*(\S+)/, 1] }
      { connected: true, site: field.("Site"), email: field.("Email"), detail: [ field.("Email"), field.("Site") ].compact.join(" on ") }
    rescue Jira::Cli::NotInstalled => e
      { connected: false, detail: "#{e.message}. Install it with: brew install atlassian/acli/acli" }
    rescue Jira::Cli::Error
      { connected: false, detail: nil }
    end
  end

  def self.connected? = status[:connected]

  def self.refresh! = Rails.cache.delete(CACHE_KEY)

  def self.log_out
    Jira::Cli.run("auth", "logout")
  ensure
    refresh!
  end
end
