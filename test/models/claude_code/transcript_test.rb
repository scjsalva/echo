require "test_helper"

class ClaudeCode::TranscriptTest < ActiveSupport::TestCase
  include FakeClaudeHome

  setup { setup_claude_home }
  teardown { teardown_claude_home }

  test "reads title, summary, last prompt and reply, and counts human turns only" do
    append_transcript(
      { type: "ai-title", aiTitle: "Fix the flaky spec" },
      human("fix the flaky spec"),
      { type: "user", timestamp: 4.minutes.ago.iso8601, message: { content: [ { type: "tool_result", tool_use_id: "x", content: "ok" } ] } },
      *assistant(id: "m1", blocks: [ { type: "text", text: "Found the race." } ]),
      { type: "system", subtype: "away_summary", content: "You're fixing a flaky spec." }
    )

    t = ClaudeCode::Transcript.for(transcript_path)

    assert_equal "Fix the flaky spec", t.title
    assert_equal "You're fixing a flaky spec.", t.summary
    assert_equal "fix the flaky spec", t.last_prompt
    assert_equal "Found the race.", t.last_reply
    assert_equal 1, t.turns
    assert_equal "claude-opus-5-5", t.model
  end

  test "counts usage once per message even when split across lines, excluding cache reads" do
    append_transcript(*assistant(id: "m1", blocks: [ { type: "thinking" }, { type: "text", text: "a" }, { type: "tool_use", name: "Bash", id: "t", input: {} } ]))

    t = ClaudeCode::Transcript.for(transcript_path)

    assert_equal 160, t.total_tokens
    assert_equal 160, t.tokens_since(1.hour.ago)
    assert_equal 5_110, t.context_tokens
    assert_equal 160, t.hourly_tokens.last
  end

  test "only parses lines appended since the last read and skips a partial last line" do
    append_transcript(human("first"))
    ClaudeCode::Transcript.for(transcript_path)
    File.open(transcript_path, "a") { it.write(human("second").to_json) }

    assert_equal "first", ClaudeCode::Transcript.for(transcript_path).last_prompt

    File.open(transcript_path, "a") { it.write("\n") }
    t = ClaudeCode::Transcript.for(transcript_path)

    assert_equal "second", t.last_prompt
    assert_equal 2, t.turns
  end

  test "tracks a Monitor until its task ends and counts its events" do
    append_transcript(
      *assistant(id: "m1", blocks: [ { type: "tool_use", name: "Monitor", id: "tu1", input: { description: "CI on PR 12", timeout_ms: 3_600_000 } } ]),
      { type: "user", timestamp: 3.minutes.ago.iso8601, toolUseResult: { taskId: "task1" }, message: { content: [ { type: "tool_result", tool_use_id: "tu1", content: "Monitor started" } ] } },
      { type: "queue-operation", operation: "enqueue", content: "<task-notification>\n<task-id>task1</task-id>\n<summary>Monitor event</summary>\n<event>CI passed</event>\n</task-notification>" }
    )

    loops = ClaudeCode::Transcript.for(transcript_path).active_loops

    assert_equal 1, loops.size
    assert_equal({ kind: "monitor", description: "CI on PR 12", events: 1 }, loops.first.slice(:kind, :description, :events))

    append_transcript({ type: "user", timestamp: 1.minute.ago.iso8601, message: { content: "<task-notification>\n<task-id>task1</task-id>\n<status>completed</status>\n</task-notification>" } })

    assert_empty ClaudeCode::Transcript.for(transcript_path).active_loops
  end

  test "drops a Monitor once it passes its timeout" do
    append_transcript(*assistant(id: "m1", at: 2.hours.ago, blocks: [ { type: "tool_use", name: "Monitor", id: "tu1", input: { description: "short", timeout_ms: 60_000 } } ]))

    assert_empty ClaudeCode::Transcript.for(transcript_path).active_loops
  end

  test "treats a ScheduleWakeup chain as one self-paced loop until it stops" do
    append_transcript(
      *assistant(id: "m1", at: 10.minutes.ago, blocks: [ { type: "tool_use", name: "ScheduleWakeup", id: "w1", input: { delaySeconds: 1200, prompt: "/babysit-prs", reason: "watching CI" } } ]),
      *assistant(id: "m2", at: 5.minutes.ago, blocks: [ { type: "tool_use", name: "ScheduleWakeup", id: "w2", input: { delaySeconds: 1200, prompt: "/babysit-prs", reason: "still watching" } } ])
    )

    loop = ClaudeCode::Transcript.for(transcript_path).active_loops.sole

    assert_equal [ "wakeup", "/babysit-prs", 1200, 2 ], loop.values_at(:kind, :description, :every, :events)
    assert_in_delta 15.minutes.from_now, loop[:next_run_at], 5

    append_transcript(*assistant(id: "m3", blocks: [ { type: "tool_use", name: "ScheduleWakeup", id: "w3", input: { stop: true } } ]))

    assert_empty ClaudeCode::Transcript.for(transcript_path).active_loops
  end

  test "schedules cron loops from their expression and ends them on CronDelete" do
    append_transcript(
      *assistant(id: "m1", blocks: [ { type: "tool_use", name: "CronCreate", id: "c1", input: { cron: "*/5 * * * *", prompt: "check the deploy" } } ]),
      { type: "user", timestamp: 3.minutes.ago.iso8601, toolUseResult: { id: "cron-9" }, message: { content: [ { type: "tool_result", tool_use_id: "c1", content: "ok" } ] } }
    )

    loop = ClaudeCode::Transcript.for(transcript_path).active_loops.sole

    assert_equal "check the deploy", loop[:description]
    assert_operator loop[:next_run_at], :<=, 5.minutes.from_now

    append_transcript(*assistant(id: "m2", blocks: [ { type: "tool_use", name: "CronDelete", id: "c2", input: { id: "cron-9" } } ]))

    assert_empty ClaudeCode::Transcript.for(transcript_path).active_loops
  end

  test "today starts at local midnight even in zones with a 30-minute offset" do
    Time.use_zone("Asia/Kolkata") do
      midnight = Time.current.beginning_of_day
      append_transcript(*assistant(id: "before", at: midnight - 10.minutes, blocks: [ { type: "text", text: "late" } ]),
        *assistant(id: "after", at: midnight + 10.minutes, blocks: [ { type: "text", text: "early" } ]))

      assert_equal 160, ClaudeCode::Transcript.for(transcript_path).tokens_since(midnight)
    end
  end

  test "picks up the name given with /rename" do
    append_transcript({ type: "ai-title", aiTitle: "Fix login" }, { type: "custom-title", customTitle: "Payments work", sessionId: SESSION_ID })

    assert_equal "Payments work", ClaudeCode::Transcript.for(transcript_path).custom_title
  end
end
