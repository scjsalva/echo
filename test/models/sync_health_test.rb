require "test_helper"

class SyncHealthTest < ActiveSupport::TestCase
  test "a run cut off long ago doesn't show as running" do
    SyncHealth.record("github", "running_since" => 40.minutes.ago.iso8601)
    assert_nil SyncHealth.props[:syncs].find { it[:source] == "github" }[:running_since]

    SyncHealth.record("github", "running_since" => 20.seconds.ago.iso8601)
    assert SyncHealth.props[:syncs].find { it[:source] == "github" }[:running_since]
  end

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

  test "restarts Echo once when no sync has started for half an hour, as after the Mac sleeps" do
    quietly(booted: 2.hours.ago) do |restart_file|
      SyncHealth.record("github", "last_attempt_at" => 10.minutes.ago.iso8601)
      SyncWatchdog.check
      assert_not restart_file.exist?

      SyncHealth.record("github", "last_attempt_at" => 40.minutes.ago.iso8601)
      SyncWatchdog.check
      assert restart_file.exist?

      restart_file.delete
      SyncWatchdog.check
      assert_not restart_file.exist?, "only once for the same pause"
    end
  end

  test "on waking, stops runs stuck since before the sleep and syncs straight away" do
    stopped = false
    CommandRunner.stub(:stop_all, -> { stopped = true }) do
      assert_enqueued_jobs(3) { SyncWatchdog.woke(40.minutes) }
    end
    assert stopped
  end

  test "doesn't restart a server that's only just started" do
    quietly(booted: 1.minute.ago) do |restart_file|
      SyncHealth.record("github", "last_attempt_at" => 2.hours.ago.iso8601)
      SyncWatchdog.check
      assert_not restart_file.exist?
    end
  end

  # The scheduler is running, so only the restart check has anything to do.
  def quietly(booted:)
    restart_file = Pathname(Dir.mktmpdir).join("restart.txt")
    SyncWatchdog.stub(:restart_file, restart_file) do
      SyncWatchdog.stub(:release_orphans, nil) do
        SyncHealth.stub(:last_scheduled_at, 10.seconds.ago) do
          Rails.application.config.x.stub(:booted_at, booted) { yield restart_file }
        end
      end
    end
  end
end
