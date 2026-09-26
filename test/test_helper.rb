ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"

Dir[Rails.root.join("test/support/**/*.rb")].each { require it }

Jira::Cli.executable = Rails.root.join("test/support/bin/acli")
Github::Cli.executable = Rails.root.join("test/support/bin/gh")
DesktopNotification.runner = ->(*) { true }
DesktopNotification.home = Pathname(Dir.mktmpdir("echo-notifier"))
# Tests keep their own change counter, so running them doesn't nudge a running Echo's pages.
Changes.path = Pathname(Dir.mktmpdir("echo-changes")).join("changes")

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
