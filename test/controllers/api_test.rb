require "test_helper"

class ApiTest < ActionDispatch::IntegrationTest
  test "dashboard returns camelCased overview data" do
    get "/api/dashboard"

    assert_response :success
    assert_includes response.parsed_body.keys, "reviewQueue"
    assert_includes response.parsed_body["shell"].keys, "waitingCount"
  end

  test "dismissing is idempotent and can be undone" do
    2.times { post "/api/dismissals", params: { item_key: "github-g1" }, as: :json }

    assert_response :no_content
    assert_equal 1, Dismissal.where(item_key: "github-g1").count

    delete "/api/dismissals/github-g1"

    assert_response :no_content
    assert_not Dismissal.exists?(item_key: "github-g1")
  end

  test "transcript is only served for a real session id" do
    get "/api/agents/not-a-session/transcript"

    assert_response :not_found
  end

  test "summary errors come back as a readable message" do
    post "/api/agents/00000000-0000-0000-0000-000000000000/summary"

    assert_response :unprocessable_content
    assert_equal "No transcript for this session", response.parsed_body["error"]
  end

  test "each agent action is routed to a controller" do
    session_id = "00000000-0000-0000-0000-000000000000"

    post "/api/agents/#{session_id}/focus"
    assert_response :unprocessable_content
    assert_equal "This session isn't running", response.parsed_body["error"]

    post "/api/ended_sessions/#{session_id}/resume"
    assert_response :unprocessable_content

    get "/api/ended_sessions"
    assert_response :success
  end

  test "time zone can be set and cleared" do
    patch "/api/settings", params: { time_zone: "Europe/London" }, as: :json

    assert_response :success
    assert_equal "Europe/London", response.parsed_body.dig("timeZone", "current")

    patch "/api/settings", params: { time_zone: "Mars/Olympus" }, as: :json
    assert_response :unprocessable_content

    patch "/api/settings", params: { time_zone: "auto" }, as: :json
    assert_equal "auto", response.parsed_body.dig("timeZone", "preference")
  end

  test "lists connections and opens Terminal to set up Jira" do
    get "/api/connections"

    assert_response :success
    assert_equal false, response.parsed_body["connections"].find { it["key"] == "jira" }["connected"]

    commands = []
    TerminalApp.stub(:run, ->(command) { commands << command }) { post "/api/connections/jira/setup" }

    assert_response :no_content
    assert_equal [ "acli jira auth login --web" ], commands
  end

  test "unknown connections can't be set up" do
    post "/api/connections/myspace/setup"

    assert_response :not_found
  end

  test "notifications can be marked read one at a time or all at once" do
    a = JiraNotification.create!(external_id: "comment-1", kind: "comment", ticket_key: "APP-1", occurred_at: 1.hour.ago)
    b = JiraNotification.create!(external_id: "comment-2", kind: "mention", ticket_key: "APP-1", occurred_at: 1.hour.ago)

    patch "/api/notifications/comment-1/read"

    assert_response :no_content
    assert a.reload.read_at
    assert_nil b.reload.read_at

    post "/api/notifications/read_all"
    assert b.reload.read_at
  end

  test "hook events from this machine are recorded" do
    post "/api/hooks", params: { session_id: "s1", hook_event_name: "PermissionRequest", tool_name: "Bash", tool_input: { command: "ls" } }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :no_content
    assert_equal "Allow Bash(ls)", SessionSignal.find_by(session_id: "s1").needs

    post "/api/hooks", params: "not json", headers: { "Content-Type" => "application/json" }
    assert_response :bad_request
  end

  test "serves system sounds by name and nothing else" do
    get "/sounds/Glass"
    assert_includes [ 200, 404 ], response.status # 404 off macOS, where the file doesn't exist
    assert_equal "audio/mp4", response.media_type if response.successful?

    get "/sounds/Nope"
    assert_response :not_found
  end

  test "renaming sends /rename to the session and needs a name" do
    typed = []
    ClaudeCode::Focus.stub(:type, ->(id, text) { typed << [ id, text ] }) do
      post "/api/agents/abc/rename", params: { name: "  Payments\nwork  " }, as: :json
      assert_response :no_content

      post "/api/agents/abc/rename", params: { name: " " }, as: :json
      assert_response :unprocessable_content
    end

    assert_equal [ [ "abc", "/rename Payments work" ] ], typed
  end

  test "marking a GitHub notification read marks its thread read on GitHub" do
    GithubNotification.create!(thread_id: "123", reason: "comment", pr_key: "acme/app#1", occurred_at: 1.hour.ago)
    GithubNotification.create!(thread_id: "review-acme/app#2", reason: "review_requested", pr_key: "acme/app#2", occurred_at: 1.hour.ago)
    calls = []

    Github::Cli.stub(:run, ->(*args, **) { calls << args }) do
      patch "/api/notifications/github-123/read"
      post "/api/notifications/read_all"
    end

    assert_equal [ %w[api -X PATCH notifications/threads/123] ], calls
    assert GithubNotification.where(read_at: nil).none?
  end

  test "github preferences reject repos that aren't owner/name" do
    patch "/api/settings", params: { github_repos: [ "not a repo" ] }, as: :json
    assert_response :unprocessable_content

    patch "/api/settings", params: { github_repos: [ "acme/app" ], github_team: [ "@dana", "ravi" ] }, as: :json
    assert_equal [ [ "acme/app" ], %w[dana ravi] ], response.parsed_body["github"].values_at("repos", "team")
  end

  test "review comments can be edited and committed but not marked sent, and freeze once the review is sent" do
    review = Review.for("acme/app#9")
    comment = review.comments.create!(path: "a.rb", line: 1, side: "RIGHT", body: "Hmm")

    patch "/api/review_comments/#{comment.id}", params: { body: "Clearer", state: "committed" }, as: :json
    assert_equal [ "Clearer", "committed" ], comment.reload.slice(:body, :state).values

    patch "/api/review_comments/#{comment.id}", params: { state: "sent" }, as: :json
    assert_response :unprocessable_content

    review.update!(status: "sent")
    patch "/api/review_comments/#{comment.id}", params: { body: "Too late" }, as: :json
    assert_response :unprocessable_content
  end

  test "starting an AI review queues it once" do
    review = Review.for("acme/app#9")

    Github::Cli.stub(:run, { "merged" => false }) do
      assert_enqueued_with(job: AiReviewJob) { post "/api/reviews/#{review.id}/ai_review" }
    end
    assert_equal "running", review.reload.ai_status

    assert_no_enqueued_jobs(only: AiReviewJob) { post "/api/reviews/#{review.id}/ai_review" }
    assert_response :success
    assert_equal "running", response.parsed_body["aiStatus"]
  end

  test "an AI review can't start on a merged PR" do
    review = Review.for("acme/app#10")

    Github::Cli.stub(:run, { "merged" => true }) { post "/api/reviews/#{review.id}/ai_review" }

    assert_response :unprocessable_content
    assert_equal "idle", review.reload.ai_status
    assert_no_enqueued_jobs only: AiReviewJob
  end

  test "PR comments are fetched on demand and camelCased" do
    Github::PullRequestComments.stub(:fetch, ->(repo, number) { [ { id: "comment-1", kind: "comment", html_url: nil, repo:, number: } ] }) do
      get "/api/github/pull_requests/acme/app.js/7/comments"
    end

    assert_response :success
    assert_equal [ { "id" => "comment-1", "kind" => "comment", "htmlUrl" => nil, "repo" => "acme/app.js", "number" => "7" } ], response.parsed_body["comments"]
  end

  test "ending a session that isn't running is a 404" do
    post "/api/agents/00000000-0000-0000-0000-000000000000/ending"

    assert_response :not_found
  end

  test "removing Echo's copy only accepts an owner/repo" do
    delete "/api/github/echo_copy", params: { repo: "../etc" }

    assert_response :unprocessable_content
  end

  test "skills can be chosen per action and per repo, and fall back to Echo's own" do
    get "/api/skill", params: { skill_action: "ai_review", repo: "acme/app" }
    assert_equal "echo:echo-review", response.parsed_body.dig("current", "id")

    patch "/api/skill", params: { skill_action: "ai_review", repo: "acme/app", skill: "echo:echo-summary" }, as: :json
    assert_response :success
    assert_equal "echo:echo-summary", Skills.for("ai_review", repo: "acme/app").id
    assert_equal "echo:echo-review", Skills.for("ai_review", repo: "acme/other").id

    patch "/api/skill", params: { skill_action: "ai_review", repo: "acme/app", skill: nil }, as: :json
    assert_equal "echo:echo-review", Skills.for("ai_review", repo: "acme/app").id
  end

  test "unknown skills and per-repo summaries are refused" do
    patch "/api/skill", params: { skill_action: "ai_review", skill: "user:../../etc" }, as: :json
    assert_response :unprocessable_content

    patch "/api/skill", params: { skill_action: "summary", repo: "acme/app", skill: "echo:echo-summary" }, as: :json
    assert_response :unprocessable_content
  end

  test "your comment can start empty to ask Claude about a line, but can't be committed empty" do
    review = Review.for("acme/app#11")

    post "/api/reviews/#{review.id}/comments", params: { path: "a.rb", line: 3, side: "RIGHT", body: "" }, as: :json
    assert_response :created
    comment = review.comments.sole

    patch "/api/review_comments/#{comment.id}", params: { state: "committed" }, as: :json
    assert_response :unprocessable_content
    assert_equal "staged", comment.reload.state

    patch "/api/review_comments/#{comment.id}", params: { state: "removed" }, as: :json
    assert_response :success
    assert_equal "removed", comment.reload.state
  end
end
