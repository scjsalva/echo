require "open3"

# Runs the GitHub CLI (gh), which handles GitHub login and API access for Echo.
# gh's login can do anything you can, so Echo only allows reads, plus two writes
# you ask for yourself: marking a notification read (keeping GitHub's inbox in
# step with Echo's) and sending a review you wrote.
module Github::Cli
  class Error < StandardError; end
  class NotInstalled < Error; end

  TIMEOUT = 30
  READ_THREAD = %r{\Anotifications/threads/\d+\z}
  CREATE_REVIEW = %r{\Arepos/[\w.-]+/[\w.-]+/pulls/\d+/reviews\z}

  mattr_accessor :executable, default: "gh"

  def self.run(*args, json: false, input: nil, timeout: TIMEOUT)
    raise ArgumentError, "Echo doesn't run `gh #{args.first(3).join(' ')}`; it only reads from GitHub" unless allowed?(args)

    output, error, status = Timeout.timeout(timeout) { Open3.capture3(executable.to_s, *args, stdin_data: input.to_s) }
    raise Error, (error.presence || output).strip.truncate(300) unless status.success?

    json ? JSON.parse(output.presence || "null") : output
  rescue Errno::ENOENT
    raise NotInstalled, "The GitHub CLI (gh) isn't installed"
  rescue Timeout::Error
    raise Error, "gh took longer than #{timeout}s"
  end

  # `gh auth status`, GET requests through `gh api`, GraphQL queries (never
  # mutations), PATCH on one notification thread to mark it read, and POST of a
  # new review on a PR.
  def self.allowed?(args)
    return true if args.first(2) == %w[auth status]
    return false unless args.first == "api"

    method = args.each_cons(2).find { |flag, _| flag.in?(%w[-X --method]) }&.last || "GET"
    path = api_path(args)
    return args.none? { it.to_s.match?(/\bmutation\b/i) } if path == "graphql"

    method == "GET" || (method == "PATCH" && path.match?(READ_THREAD)) || (method == "POST" && path.match?(CREATE_REVIEW))
  end

  FLAGS_WITH_VALUES = %w[-X --method -f --raw-field -F --field -H --header -q --jq -t --template --input].freeze

  # The endpoint in `gh api [flags] <endpoint> [flags]`: the first word that isn't a flag or a flag's value.
  def self.api_path(args)
    skip = false
    args.drop(1).each do |arg|
      if skip then skip = false
      elsif FLAGS_WITH_VALUES.include?(arg) then skip = true
      elsif !arg.start_with?("-") then return arg
      end
    end
    ""
  end
end
