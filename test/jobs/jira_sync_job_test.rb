require "test_helper"

class JiraSyncJobTest < ActiveJob::TestCase
  test "syncs only when Jira is connected" do
    runs = 0
    sync = Object.new
    sync.define_singleton_method(:run) { runs += 1 }

    Jira::Sync.stub(:new, sync) do
      Jira::Connection.stub(:connected?, false) { JiraSyncJob.perform_now }
      Jira::Connection.stub(:connected?, true) { JiraSyncJob.perform_now }
    end

    assert_equal 1, runs
  end

  test "is scheduled every minute" do
    assert_equal({ "class" => "JiraSyncJob", "schedule" => "every minute" }, Rails.application.config_for(:recurring, env: "production")["jira_sync"].stringify_keys)
  end
end
