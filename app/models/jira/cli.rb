require "open3"

# Runs the Atlassian CLI (acli), which handles Jira login and API access for Echo.
# acli's login grants write access too, so Echo only allows the read-only
# commands below; anything else is refused before acli runs.
module Jira::Cli
  class Error < StandardError; end
  class NotInstalled < Error; end

  ALLOWED = [
    %w[auth status], %w[auth logout],
    %w[workitem search], %w[workitem view], %w[workitem comment list]
  ].freeze

  TIMEOUT = 30

  mattr_accessor :executable, default: "acli"

  # Returns stdout, or parsed JSON when `json:` is set. Raises with acli's own message on failure.
  def self.run(*args, json: false)
    unless ALLOWED.any? { args.first(it.size) == it }
      raise ArgumentError, "Echo doesn't run `acli jira #{args.first(3).join(' ')}`; it only reads from Jira"
    end

    output, error, status = Timeout.timeout(TIMEOUT) { Open3.capture3(executable.to_s, "jira", *args, *([ "--json" ] if json)) }
    raise Error, (error.presence || output).strip.delete_prefix("✗ Error: ").truncate(300) unless status.success?

    json ? JSON.parse(output) : output
  rescue Errno::ENOENT
    raise NotInstalled, "The Atlassian CLI (acli) isn't installed"
  rescue Timeout::Error
    raise Error, "acli took longer than #{TIMEOUT}s"
  end
end
