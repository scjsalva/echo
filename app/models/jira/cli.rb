require "open3"

# Runs the Atlassian CLI (acli), which handles Jira login and API access for Echo.
# acli's login grants write access too, so Echo only allows the read-only
# commands below, plus one write you ask for yourself: assigning one ticket to
# you, or taking you off it. Anything else is refused before acli runs.
module Jira::Cli
  class Error < StandardError; end
  class NotInstalled < Error; end

  ALLOWED = [
    %w[auth status], %w[auth logout],
    %w[workitem search], %w[workitem view], %w[workitem comment list],
    %w[board search], %w[board view], %w[board list-sprints], %w[filter search]
  ].freeze

  # Exactly these, for one ticket: `workitem assign --key APP-1 --assignee @me --yes`, or with --remove-assignee.
  ASSIGN = [ [ "--assignee", "@me", "--yes" ], [ "--remove-assignee", "--yes" ] ].freeze
  KEY = /\A[A-Z][A-Z0-9_]+-\d+\z/

  TIMEOUT = 30

  mattr_accessor :executable, default: "acli"

  # Returns stdout, or parsed JSON when `json:` is set. Raises with acli's own message on failure.
  def self.run(*args, json: false)
    unless ALLOWED.any? { args.first(it.size) == it } || assignment?(args)
      raise ArgumentError, "Echo doesn't run `acli jira #{args.first(3).join(' ')}`; it only reads from Jira"
    end

    output, error, status = CommandRunner.capture(executable.to_s, "jira", *args, *([ "--json" ] if json), timeout: TIMEOUT)
    raise Error, (error.presence || output).strip.delete_prefix("✗ Error: ").truncate(300) unless status.success?

    json ? JSON.parse(output) : output
  rescue Errno::ENOENT
    raise NotInstalled, "The Atlassian CLI (acli) isn't installed"
  rescue CommandRunner::TimedOut
    raise Error, "acli took longer than #{TIMEOUT}s"
  rescue CommandRunner::Stopped
    raise Error, "acli was stopped when the computer woke up"
  end

  def self.assignment?(args)
    args.first(3) == %w[workitem assign --key] && args[3].to_s.match?(KEY) && ASSIGN.include?(args.drop(4))
  end
end
