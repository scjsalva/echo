require "test_helper"

class Jira::ConnectionTest < ActiveSupport::TestCase
  teardown { ENV.delete("FAKE_ACLI_LOGGED_IN") }

  test "is connected when acli is logged in, with its account details" do
    ENV["FAKE_ACLI_LOGGED_IN"] = "1"

    assert_equal({ connected: true, site: "example.atlassian.net", email: "me@example.com", detail: "me@example.com on example.atlassian.net" },
      Jira::Connection.status)
  end

  test "is disconnected when acli is logged out" do
    assert_not Jira::Connection.connected?
  end

  test "explains how to install acli when it's missing" do
    Jira::Cli.stub(:executable, "/nonexistent/acli") do
      assert_match "brew install atlassian/acli/acli", Jira::Connection.status[:detail]
    end
  end

  test "only read-only acli commands can run" do
    error = assert_raises(ArgumentError) { Jira::Cli.run("workitem", "edit", "--key", "APP-1") }
    assert_match "only reads from Jira", error.message

    assert_raises(ArgumentError) { Jira::Cli.run("workitem", "comment", "create") }
  end
end
