require "test_helper"

class ClaudeCode::SessionTest < ActiveSupport::TestCase
  include FakeClaudeHome

  setup { setup_claude_home }
  teardown { teardown_claude_home }

  test "builds an agent from the session registry and its transcript" do
    append_transcript({ type: "ai-title", aiTitle: "Fix login" }, human("fix login"), *assistant(id: "m1", blocks: [ { type: "text", text: "Done." } ]))

    agent = ClaudeCode::Session.live.sole.to_agent

    assert_equal [ "app-a1", "~/Projects/app", "busy", "Opus 5.5", "Fix login", "fix login", "Done." ],
      agent.values_at(:name, :cwd, :status, :model, :title, :last_prompt, :last_reply)
    assert_equal 160, agent[:tokens_today]
    assert_equal 3, agent[:context_percent]
  end

  test "a waiting session is waiting on the user" do
    setup_claude_home(status: "waiting")

    agent = ClaudeCode::Session.live.sole.to_agent

    assert_equal "blocked", agent[:status]
    assert_equal "Waiting for your input", agent[:needs]
  end

  test "ignores sessions whose process has exited" do
    write_json("sessions/999999.json", { pid: 999_999, sessionId: "dead", status: "idle", startedAt: 0, updatedAt: 0 })

    assert_equal [ SESSION_ID ], ClaudeCode::Session.live.map(&:id)
  end

  test "lists recent subagents and adds their tokens to the session" do
    append_transcript(human("go"))
    sub = transcript_path.dirname.join(SESSION_ID, "subagents/agent-abc.jsonl")
    append_transcript(*assistant(id: "s1", blocks: [ { type: "text", text: "Found 3 call sites" } ]), path: sub)
    write_json(sub.relative_path_from(@claude_home).sub_ext(".meta.json").to_s, { agentType: "Explore", description: "Find call sites" })

    agent = ClaudeCode::Session.live.sole.to_agent

    assert_equal [ { type: "Explore", name: "Find call sites", status: "running", result: "Found 3 call sites" } ],
      agent[:subagents].map { it.except(:active) }
    assert_equal 160, agent[:tokens_today]
  end

  test "reads a missing transcript as an empty session" do
    agent = ClaudeCode::Session.live.sole.to_agent

    assert_equal [ "unknown", 0, [] ], agent.values_at(:model, :tokens_today, :loops)
  end

  test "each loop carries the tokens its session has used since the loop started" do
    append_transcript(*assistant(id: "m1", at: 3.hours.ago, blocks: [ { type: "text", text: "before" } ]),
      *assistant(id: "m2", at: 10.minutes.ago, blocks: [ { type: "tool_use", name: "Monitor", id: "tu1", input: { description: "CI", persistent: true } } ]))

    loop = ClaudeCode::Session.live.sole.to_agent[:loops].sole

    assert_equal 160, loop[:session_tokens_since_start]
  end

  test "a hook-reported block marks the session as waiting on you with the request" do
    SessionSignal.create!(session_id: SESSION_ID, needs: "Allow Bash(git push)")

    agent = ClaudeCode::Session.live.sole.to_agent

    assert_equal [ "blocked", "Allow Bash(git push)" ], agent.values_at(:status, :needs)
  end

  test "a renamed session goes by its new name and keeps its handle" do
    append_transcript({ type: "custom-title", customTitle: "Payments work" })

    agent = ClaudeCode::Session.live.sole.to_agent

    assert_equal [ "Payments work", "app-a1", true ], agent.values_at(:name, :handle, :renamed)
  end
end
