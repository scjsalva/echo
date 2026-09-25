# On-demand session summary from a headless Haiku call. Costs tokens, so it only
# runs when the user asks, and the result is reused until the transcript grows.
class ClaudeCode::Summary
  MODEL = "haiku"
  TIMEOUT = 90
  MESSAGE_LIMIT = 40

  class Error < StandardError; end

  def self.for(session_id)
    path = ClaudeCode.transcript_path(session_id) or raise Error, "No transcript for this session"

    Rails.cache.fetch([ "claude-summary", session_id, File.size(path) ]) do
      { text: generate(ClaudeCode::Transcript.messages(path, limit: MESSAGE_LIMIT)), model: "Haiku", generated_at: Time.current }
    end
  end

  def self.generate(messages)
    conversation = messages.map { "#{it[:role]}: #{it[:text].to_s.truncate(1_500)}" }.join("\n\n")
    # Run from tmp/ with no tools, MCP, hooks or saved session, so it stays cheap and invisible.
    command = [ "claude", "-p", "--model", MODEL, "--no-session-persistence", "--tools", "", "--strict-mcp-config",
      "--setting-sources", "project", "--system-prompt", [ Skills.for("summary").instructions, ClaudeCode::Context.prompt ].compact_blank.join("\n\n") ]
    output, status = ClaudeCode::Headless.run(command, input: conversation, chdir: Rails.root.join("tmp"), timeout: TIMEOUT, purpose: "summary")
    raise Error, output.strip.truncate(300) unless status.success?

    output.strip
  rescue ClaudeCode::Headless::Timeout
    raise Error, "Claude took longer than #{TIMEOUT}s"
  rescue Errno::ENOENT
    raise Error, "The claude command isn't on PATH"
  end

  private_class_method :generate
end
