require "test_helper"

class ClaudeCode::EndedSessionTest < ActiveSupport::TestCase
  include FakeClaudeHome

  setup { setup_claude_home }
  teardown { teardown_claude_home }

  test "builds an ended session with the command to resume it" do
    append_transcript(human("live one"))
    ended_transcript(1, title: "Old work", cwd: File.join(Dir.home, "Projects/my app"), branch: "APP-1")

    session = ClaudeCode::EndedSession.page(live_ids: [ SESSION_ID ])[:items].sole

    assert_equal [ ended_id(1), "Old work", "~/Projects/my app", "APP-1", 1, 160, "Done." ],
      session.values_at(:id, :title, :cwd, :branch, :turns, :tokens_total, :last_reply)
    assert_equal "cd #{Dir.home}/Projects/my\\ app && claude --resume #{ended_id(1)}", session[:resume_command]
  end

  test "pages newest first with a cursor" do
    5.times { ended_transcript(it, title: "Session #{it}", modified: it.hours.ago) }

    first = ClaudeCode::EndedSession.page(live_ids: [], limit: 2)
    second = ClaudeCode::EndedSession.page(live_ids: [], limit: 2, before: first[:next_cursor])
    last = ClaudeCode::EndedSession.page(live_ids: [], limit: 2, before: second[:next_cursor])

    assert_equal [ "Session 0", "Session 1" ], first[:items].map { it[:title] }
    assert_equal [ "Session 2", "Session 3" ], second[:items].map { it[:title] }
    assert_equal [ "Session 4" ], last[:items].map { it[:title] }
    assert_nil last[:next_cursor]
  end

  test "searches title, folder and branch" do
    ended_transcript(1, title: "Fix login", branch: "APP-77")
    ended_transcript(2, title: "Write docs")

    assert_equal [ "Fix login" ], ClaudeCode::EndedSession.page(live_ids: [], query: "app-77")[:items].map { it[:title] }
  end

  test "skips transcripts with no prompts" do
    append_transcript({ type: "ai-title", aiTitle: "Nothing asked" }, path: transcript_path(ended_id(1)))

    assert_empty ClaudeCode::EndedSession.page(live_ids: [])[:items]
  end

  private

  def ended_id(n) = format("99999999-8888-7777-6666-%012d", n)

  def ended_transcript(n, title:, cwd: nil, branch: nil, modified: nil)
    path = transcript_path(ended_id(n))
    append_transcript({ type: "ai-title", aiTitle: title }, human("go").merge(cwd:, gitBranch: branch).compact,
      *assistant(id: "m#{n}", blocks: [ { type: "text", text: "Done." } ]), path:)
    File.utime(modified.to_time, modified.to_time, path) if modified
  end
end
