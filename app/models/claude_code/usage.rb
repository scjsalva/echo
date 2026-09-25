# Tokens used across every Claude Code transcript, including ended sessions and subagents.
module ClaudeCode::Usage
  def self.tokens_today
    since = Time.current.beginning_of_day
    Dir[ClaudeCode.root.join("projects/**/*.jsonl")]
      .select { File.mtime(it) >= since }
      .sum { ClaudeCode::Transcript.for(it)&.tokens_since(since).to_i }
  end
end
