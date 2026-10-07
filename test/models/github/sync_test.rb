require "test_helper"

class Github::SyncTest < ActiveSupport::TestCase
  ME = "octo".freeze

  setup do
    @mine = []
    @requested = []
    @queue = []
    @threads = []
    @comments = {}
    @replies = []
    Github::Preferences.update(repos: [ "acme/app" ])
  end

  test "stores PRs, flags review requests and skips the queue's copies of them" do
    @mine << pr(1, author: ME)
    @requested << pr(2, author: "dana")
    @queue.push(pr(2, author: "dana"), pr(3, author: "ravi"))

    sync

    assert_equal %w[acme/app#1 acme/app#2 acme/app#3], GithubPullRequest.order(:key).pluck(:key)
    assert GithubPullRequest.find_by(key: "acme/app#2").requested_from_me
    assert GithubPullRequest.find_by(key: "acme/app#1").mine
  end

  test "a review request waits on you until you're no longer requested" do
    @requested << pr(2, author: "dana")
    sync
    request = GithubNotification.find_by(reason: "review_requested")
    assert_nil request.resolved_at

    @requested.clear
    @queue << pr(2, author: "dana", reviews: [ review(ME, "APPROVED", 1.minute.ago) ])
    sync

    assert_equal "You reviewed it", request.reload.resolution
  end

  test "records comments on your threads, skipping your own and bots'" do
    sync # First sync seeds; later ones notify.
    @threads.push(thread(10, "comment", 2.minutes.ago, comment: 100), thread(11, "comment", 1.minute.ago, comment: 101),
      thread(12, "comment", 1.minute.ago, comment: 102))
    @comments.merge!(100 => [ "dana", "Can you look?" ], 101 => [ ME, "Done" ], 102 => [ "github-actions[bot]", "CI report" ])

    sync

    assert_equal [ [ "10", "dana", "Can you look?", nil ] ], GithubNotification.where(reason: "comment").where.not(actor: nil).pluck(:thread_id, :actor, :body, :read_at)
    assert GithubNotification.find_by(thread_id: "11").read_at
  end

  test "changes requested on someone else's PR is news, not swallowed" do
    @queue << pr(2, author: "ravi")
    sync
    @threads << thread(31, "subscribed", 1.minute.ago, comment: nil)
    @reviews = [ { "user" => { "login" => "dana" }, "state" => "CHANGES_REQUESTED", "submitted_at" => 1.minute.ago.iso8601, "body" => "Needs a test" } ]
    sync

    assert_equal [ "changes_requested_other", "dana", nil ], GithubNotification.find_by(thread_id: "31").slice(:reason, :actor, :read_at).values
  end

  test "a reply on a comment thread says what was replied, not that they reviewed" do
    sync
    @threads << thread(32, "author", 1.minute.ago, comment: nil)
    @reviews = [ { "id" => 7, "user" => { "login" => "kwame" }, "state" => "COMMENTED", "submitted_at" => 1.minute.ago.iso8601, "body" => "" } ]
    @review_comments = [ { "id" => 4, "body" => "fixed in 696214f", "in_reply_to_id" => 3 } ]
    @thread_comments = [ { "id" => 3, "user" => { "login" => ME } }, { "id" => 4, "user" => { "login" => "kwame" }, "in_reply_to_id" => 3 } ]
    sync

    assert_equal [ "reply", "kwame", "fixed in 696214f" ], GithubNotification.find_by(thread_id: "32").slice(:reason, :actor, :body).values
  end

  test "a reply counts if you've commented in the thread, even if you didn't start it" do
    sync
    @threads << thread(34, "author", 1.minute.ago, comment: nil)
    @reviews = [ { "id" => 7, "user" => { "login" => "kwame" }, "state" => "COMMENTED", "submitted_at" => 1.minute.ago.iso8601, "body" => "" } ]
    @review_comments = [ { "id" => 5, "body" => "sure", "in_reply_to_id" => 3 } ]
    @thread_comments = [ { "id" => 3, "user" => { "login" => "dana" } }, { "id" => 4, "user" => { "login" => ME }, "in_reply_to_id" => 3 },
                         { "id" => 5, "user" => { "login" => "kwame" }, "in_reply_to_id" => 3 } ]
    sync

    assert_equal [ "reply", nil ], GithubNotification.find_by(thread_id: "34").slice(:reason, :read_at).values
  end

  test "a reply in someone else's thread isn't news, unless it mentions you" do
    sync
    @threads.push(thread(35, "author", 1.minute.ago, comment: nil), thread(36, "mention", 1.minute.ago, comment: nil))
    @reviews = [ { "id" => 7, "user" => { "login" => "kwame" }, "state" => "COMMENTED", "submitted_at" => 1.minute.ago.iso8601, "body" => "" } ]
    @review_comments = [ { "id" => 5, "body" => "agreed", "in_reply_to_id" => 3 } ]
    @thread_comments = [ { "id" => 3, "user" => { "login" => "dana" } }, { "id" => 5, "user" => { "login" => "kwame" }, "in_reply_to_id" => 3 } ]
    sync

    assert GithubNotification.find_by(thread_id: "35").read_at
    assert_equal [ "reply", nil ], GithubNotification.find_by(thread_id: "36").slice(:reason, :read_at).values
  end

  test "a review request in GitHub's inbox that isn't otherwise news doesn't wait on you a second time" do
    sync
    @requested << pr(2, author: "dana")
    @threads.push(thread(37, "review_requested", 1.minute.ago, comment: nil))
    @reviews = [ { "id" => 7, "user" => { "login" => "ravi" }, "state" => "COMMENTED", "submitted_at" => 1.minute.ago.iso8601, "body" => "" } ]
    @review_comments = [ { "id" => 5, "body" => "agreed", "in_reply_to_id" => 3 } ]
    @thread_comments = [ { "id" => 3, "user" => { "login" => "dana" } }, { "id" => 5, "user" => { "login" => "ravi" }, "in_reply_to_id" => 3 } ]
    sync

    assert_equal "comment", GithubNotification.find_by(thread_id: "37").reason
    waiting = Dashboard.new(data: { github_notifications: Github::DashboardData.notifications, pull_requests: Github::DashboardData.pull_requests }, dismissed_keys: [])
      .waiting_items.select { it[:status] == "open" && it[:kind] == "review_requested" }
    assert_equal [ "acme/app#2" ], waiting.map { it.dig(:ref, :pr_key) }
  end

  test "says what happened when the activity wasn't a comment" do
    sync
    @threads << thread(30, "author", 1.minute.ago, comment: nil)
    @reviews = [ { "user" => { "login" => "kwame" }, "state" => "APPROVED", "submitted_at" => 1.minute.ago.iso8601, "body" => "" } ]
    sync

    assert_equal [ "approved", "kwame" ], GithubNotification.find_by(thread_id: "30").slice(:reason, :actor).values
  end

  test "a mention clears once you comment on the PR" do
    sync
    @threads << thread(20, "mention", 5.minutes.ago, comment: 200)
    @comments[200] = [ "ravi", "@octo thoughts?" ]
    sync
    mention = GithubNotification.find_by(reason: "mention")
    assert_nil mention.resolved_at

    @replies << { "user" => { "login" => ME }, "created_at" => Time.current.iso8601 }
    sync

    assert_equal "You replied on GitHub", mention.reload.resolution
  end

  test "changes requested on your PR wait until you push again, and pushes after your review are news" do
    @mine << pr(1, author: ME, decision: "CHANGES_REQUESTED", reviews: [ review("dana", "CHANGES_REQUESTED", 10.minutes.ago, body: "Rename this") ], last_commit: 20.minutes.ago)
    @queue << pr(3, author: "ravi", reviews: [ review(ME, "COMMENTED", 10.minutes.ago) ], last_commit: 2.minutes.ago)
    sync

    changes = GithubNotification.find_by(reason: "changes_requested")
    assert_equal [ "dana", "Rename this", nil ], changes.slice(:actor, :body, :resolved_at).values
    assert GithubNotification.exists?(reason: "follow_up", pr_key: "acme/app#3")

    @mine[0] = pr(1, author: ME, decision: "CHANGES_REQUESTED", reviews: [ review("dana", "CHANGES_REQUESTED", 10.minutes.ago) ], last_commit: 1.minute.ago)
    sync

    assert_equal "You pushed new commits", changes.reload.resolution
  end

  private

  test "a teammate's PR marked ready since the last sync is news, but ones already open aren't" do
    Github::Preferences.update(team: %w[dana])
    @queue.push(pr(2, author: "dana"), pr(3, author: "ravi"))
    sync # First sync seeds.
    Setting[Github::Sync::SYNCED_AT] = 5.minutes.ago.iso8601

    @queue.push(pr(4, author: "dana", ready_at: 1.minute.ago), pr(5, author: "ravi", ready_at: 1.minute.ago))
    sync

    assert_equal [ [ "acme/app#4", "dana" ] ], GithubNotification.where(reason: "ready_for_review").pluck(:pr_key, :actor)
    sync
    assert_equal 1, GithubNotification.where(reason: "ready_for_review").count
  end

  test "a re-request after you've reviewed is a new review request, asking you to look again" do
    @requested << pr(2, author: "dana")
    sync
    first = GithubNotification.find_by(reason: "review_requested")

    @requested.clear
    @queue << pr(2, author: "dana", reviews: [ review(ME, "COMMENTED", 2.hours.ago) ])
    sync
    assert_equal "You reviewed it", first.reload.resolution

    @queue.clear
    @requested << pr(2, author: "dana", reviews: [ review(ME, "COMMENTED", 2.hours.ago) ])
    2.times { sync }
    again = GithubNotification.where(reason: "re_review_requested")
    assert_equal 1, again.count, "one per round"
    assert_nil again.first.resolved_at
    assert_equal "dana asked you to review again", Github::NotificationText.for(reason: "re_review_requested", actor: "dana", body: nil)
  end

  test "a PR you reviewed looks ready once the author pushed, answered your threads, CI passes and they've gone quiet" do
    Notifier.update(looks_ready: true)
    Rails.cache.clear
    @review_threads = [ review_thread([ ME, 3.hours.ago ], [ "dana", 50.minutes.ago ]) ]
    @queue << pr(2, author: "dana", reviews: [ review(ME, "COMMENTED", 3.hours.ago) ], last_commit: 1.hour.ago)
    2.times do
      Rails.cache.clear
      sync
    end

    ready = GithubNotification.where(reason: "looks_ready")
    assert_equal 1, ready.count, "once per round"
    assert_equal "dana", ready.first.actor
  end

  test "doesn't guess it's ready for a bot, an unanswered thread, a fresh push, or while turned off" do
    reviewed = { reviews: [ review(ME, "COMMENTED", 3.hours.ago) ] }
    answered = [ review_thread([ ME, 3.hours.ago ], [ "dana", 50.minutes.ago ]) ]
    {
      "turned off" => [ false, pr(2, author: "dana", **reviewed), answered ],
      "a bot" => [ true, pr(2, author: "renovate", bot: true, **reviewed), [] ],
      "an unanswered thread" => [ true, pr(2, author: "dana", **reviewed), [ review_thread([ ME, 3.hours.ago ]) ] ],
      "a fresh push" => [ true, pr(2, author: "dana", last_commit: 10.minutes.ago, **reviewed), answered ]
    }.each do |what, (on, pull, threads)|
      Notifier.update(looks_ready: on)
      Rails.cache.clear
      @queue = [ pull ]
      @review_threads = threads
      sync
      assert_equal 0, GithubNotification.where(reason: "looks_ready").count, "not for #{what}"
    end
  end

  def sync
    cli = lambda do |*args, json: false, timeout: nil|
      path = Github::Cli.api_path(args)
      case path
      when "graphql"
        if args.any? { it.include?("reviewThreads") }
          next { "data" => { "repository" => { "pullRequest" => { "reviewThreads" => { "nodes" => @review_threads || [], "pageInfo" => { "hasNextPage" => false } } } } } }
        end
        queue = args.any? { it == "withQueue=true" }
        { "data" => { "viewer" => { "login" => ME }, "mine" => { "nodes" => @mine }, "requested" => { "nodes" => @requested },
          "queue" => (queue ? { "nodes" => @queue } : nil) } }
      when /\Anotifications/ then @threads
      when %r{issues/comments/(\d+)\z}
        login, body = @comments.fetch(Regexp.last_match(1).to_i)
        { "user" => { "login" => login }, "body" => body }
      when %r{/issues/\d+/comments} then @replies
      when %r{/reviews/\d+/comments} then @review_comments || []
      when %r{/pulls/\d+/comments} then args.include?("--slurp") ? [ @thread_comments || [] ] : []
      when %r{/pulls/\d+/reviews} then @reviews || []
      when %r{/pulls/\d+\z} then { "state" => "open" }
      else []
      end
    end
    Github::Connection.stub(:login, ME) { Github::Cli.stub(:run, cli) { Github::Sync.new.run } }
  end

  def pr(number, author:, decision: nil, reviews: [], last_commit: 1.hour.ago, ready_at: nil, bot: false)
    { "number" => number, "title" => "PR #{number}", "url" => "https://github.com/acme/app/pull/#{number}", "isDraft" => false,
      "createdAt" => 1.day.ago.iso8601, "updatedAt" => 1.hour.ago.iso8601, "additions" => 1, "deletions" => 1, "changedFiles" => 1,
      "body" => "", "author" => { "login" => author, "__typename" => bot ? "Bot" : "User" }, "repository" => { "nameWithOwner" => "acme/app" }, "reviewDecision" => decision,
      "commits" => { "totalCount" => 1, "nodes" => [ { "commit" => { "committedDate" => last_commit.iso8601, "statusCheckRollup" => { "state" => "SUCCESS" } } } ] },
      "reviewRequests" => { "nodes" => [] }, "latestReviews" => { "nodes" => reviews },
      "readyEvents" => { "nodes" => ready_at ? [ { "createdAt" => ready_at.iso8601 } ] : [] } }
  end

  def review_thread(*comments, resolved: false)
    { "id" => "T_#{comments.first.first}", "isResolved" => resolved, "isOutdated" => false, "path" => "app/x.rb", "line" => 1, "startLine" => nil,
      "originalLine" => 1, "diffSide" => "RIGHT",
      "comments" => { "nodes" => comments.map { |login, at| { "id" => "c-#{login}-#{at.to_i}", "author" => { "login" => login }, "body" => "…", "createdAt" => at.iso8601, "url" => nil } } } }
  end

  def review(login, state, at, body: "") = { "author" => { "login" => login }, "state" => state, "submittedAt" => at.iso8601, "body" => body }

  def thread(id, reason, at, comment:)
    { "id" => id.to_s, "reason" => reason, "updated_at" => at.iso8601,
      "subject" => { "type" => "PullRequest", "title" => "PR 2", "url" => "https://api.github.com/repos/acme/app/pulls/2",
        "latest_comment_url" => comment ? "https://api.github.com/repos/acme/app/issues/comments/#{comment}" : "https://api.github.com/repos/acme/app/pulls/2" } }
  end
end
