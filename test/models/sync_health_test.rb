require "test_helper"

class SyncHealthTest < ActiveSupport::TestCase
  test "skips a run while another of the same sync is still going" do
    ran = false
    SyncHealth.track("jira") do
      SyncHealth.track("jira") { ran = true }
    end

    assert_not ran
    assert SyncHealth.state("jira")["last_skipped_at"]
  end

  test "records successes, and counts failures until one succeeds" do
    SyncHealth.track("github") { :ok }
    assert_equal "ok", SyncHealth.props[:syncs].find { it[:source] == "github" }[:status]

    3.times { assert_raises(Github::Cli::Error) { SyncHealth.track("github") { raise Github::Cli::Error, "gh took longer than 60s" } } }
    github = SyncHealth.props[:syncs].find { it[:source] == "github" }
    assert_equal [ "failing", 3, "gh took longer than 60s" ], github.values_at(:status, :failures, :last_error)

    SyncHealth.track("github") { :ok }
    assert_equal 0, SyncHealth.props[:syncs].find { it[:source] == "github" }[:failures]
  end
end

class SyncWatchdogTest < ActiveJob::TestCase
  test "runs the syncs itself when the scheduler goes quiet, and stands down when it's back" do
    SyncWatchdog.stub(:release_orphans, nil) do
      SyncHealth.stub(:last_scheduled_at, 4.minutes.ago) do
        assert_enqueued_jobs(3) { SyncWatchdog.check }
      end
      assert Setting[SyncWatchdog::COVERING]

      SyncHealth.stub(:last_scheduled_at, 10.seconds.ago) do
        assert_no_enqueued_jobs { SyncWatchdog.check }
      end
      assert_nil Setting[SyncWatchdog::COVERING]
    end
  end
end
