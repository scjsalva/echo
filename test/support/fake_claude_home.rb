# Builds a throwaway ~/.claude with one live session for Claude Code reader tests.
module FakeClaudeHome
  SESSION_ID = "11111111-2222-3333-4444-555555555555".freeze

  def setup_claude_home(status: "busy", pid: Process.pid)
    @claude_home = Pathname(Dir.mktmpdir("claude-home"))
    @previous_claude_dir = ENV["CLAUDE_CONFIG_DIR"]
    ENV["CLAUDE_CONFIG_DIR"] = @claude_home.to_s
    ClaudeCode::Transcript.clear_cache

    write_json("sessions/#{pid}.json", {
      pid:, sessionId: SESSION_ID, cwd: File.join(Dir.home, "Projects/app"), status:, name: "app-a1",
      startedAt: 2.hours.ago.to_i * 1000, updatedAt: 1.minute.ago.to_i * 1000
    })
  end

  def teardown_claude_home
    ENV["CLAUDE_CONFIG_DIR"] = @previous_claude_dir
    FileUtils.rm_rf(@claude_home)
    ClaudeCode::Transcript.clear_cache
  end

  def transcript_path(name = SESSION_ID) = @claude_home.join("projects/-Users-me-Projects-app/#{name}.jsonl")

  def append_transcript(*entries, path: transcript_path)
    FileUtils.mkdir_p(path.dirname)
    File.open(path, "a") { |f| entries.each { f.puts(it.to_json) } }
  end

  def write_json(relative, data)
    path = @claude_home.join(relative)
    FileUtils.mkdir_p(path.dirname)
    path.write(data.to_json)
  end

  def human(text, at: 5.minutes.ago) = { type: "user", timestamp: at.iso8601(3), origin: { kind: "human" }, message: { role: "user", content: text } }

  def assistant(id:, blocks:, at: 4.minutes.ago, usage: { input_tokens: 10, cache_creation_input_tokens: 100, cache_read_input_tokens: 5_000, output_tokens: 50 }, model: "claude-opus-5-5")
    blocks.map { { type: "assistant", timestamp: at.iso8601(3), message: { id:, model:, usage:, content: [ it ] } } }
  end
end
