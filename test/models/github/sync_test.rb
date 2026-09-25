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

  test "says what happened when the activity wasn't a comment" do
    sync
    @threads << thread(30, "author", 1.minute.ago, comment: nil)
    @reviews = [ { "user" => { "login" => "jhon50" }, "state" => "APPROVED", "submitted_at" => 1.minute.ago.iso8601, "body" => "" } ]
    sync

    assert_equal [ "approved", "jhon50" ], GithubNotification.find_by(thread_id: "30").slice(:reason, :actor).values
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

  def sync
    cli = lambda do |*args, json: false|
      path = Github::Cli.api_path(args)
      case path
      when "graphql"
        queue = args.any? { it == "withQueue=true" }
        { "data" => { "viewer" => { "login" => ME }, "mine" => { "nodes" => @mine }, "requested" => { "nodes" => @requested },
          "queue" => (queue ? { "nodes" => @queue } : nil) } }
      when /\Anotifications/ then @threads
      when %r{issues/comments/(\d+)\z}
        login, body = @comments.fetch(Regexp.last_match(1).to_i)
        { "user" => { "login" => login }, "body" => body }
      when %r{/issues/\d+/comments} then @replies
      when %r{/pulls/\d+/reviews} then @reviews || []
      when %r{/pulls/\d+\z} then { "state" => "open" }
      else []
      end
    end
    Github::Connection.stub(:login, ME) { Github::Cli.stub(:run, cli) { Github::Sync.new.run } }
  end

  def pr(number, author:, decision: nil, reviews: [], last_commit: 1.hour.ago, ready_at: nil)
    { "number" => number, "title" => "PR #{number}", "url" => "https://github.com/acme/app/pull/#{number}", "isDraft" => false,
      "createdAt" => 1.day.ago.iso8601, "updatedAt" => 1.hour.ago.iso8601, "additions" => 1, "deletions" => 1, "changedFiles" => 1,
      "body" => "", "author" => { "login" => author }, "repository" => { "nameWithOwner" => "acme/app" }, "reviewDecision" => decision,
      "commits" => { "totalCount" => 1, "nodes" => [ { "commit" => { "committedDate" => last_commit.iso8601, "statusCheckRollup" => { "state" => "SUCCESS" } } } ] },
      "reviewRequests" => { "nodes" => [] }, "latestReviews" => { "nodes" => reviews },
      "readyEvents" => { "nodes" => ready_at ? [ { "createdAt" => ready_at.iso8601 } ] : [] } }
  end

  def review(login, state, at, body: "") = { "author" => { "login" => login }, "state" => state, "submittedAt" => at.iso8601, "body" => body }

  def thread(id, reason, at, comment:)
    { "id" => id.to_s, "reason" => reason, "updated_at" => at.iso8601,
      "subject" => { "type" => "PullRequest", "title" => "PR 2", "url" => "https://api.github.com/repos/acme/app/pulls/2",
        "latest_comment_url" => comment ? "https://api.github.com/repos/acme/app/issues/comments/#{comment}" : "https://api.github.com/repos/acme/app/pulls/2" } }
  end
end
