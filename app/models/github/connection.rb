# Whether gh is logged in to GitHub. Checked at most every 30 seconds.
module Github::Connection
  LOGIN_COMMAND = "gh auth login --web --hostname github.com".freeze
  CACHE_KEY = "github-connection".freeze

  def self.status
    Rails.cache.fetch(CACHE_KEY, expires_in: 30.seconds) do
      output = Github::Cli.run("auth", "status")
      login = output[/Logged in to github\.com account (\S+)/, 1]
      { connected: true, login:, detail: "Signed in to GitHub as #{login} through gh" }
    rescue Github::Cli::NotInstalled => e
      { connected: false, detail: "#{e.message}. Install it with: brew install gh" }
    rescue Github::Cli::Error
      { connected: false, detail: nil }
    end
  end

  def self.connected? = status[:connected]
  def self.login = status[:login]
  def self.refresh! = Rails.cache.delete(CACHE_KEY)
end
