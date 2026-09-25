# Reads Claude Code's local state (~/.claude). These files are internal to
# Claude Code and undocumented, so everything here parses defensively.
module ClaudeCode
  def self.root
    Pathname(ENV.fetch("CLAUDE_CONFIG_DIR", File.expand_path("~/.claude")))
  end

  def self.available?
    root.join("sessions").directory?
  end

  def self.transcript_path(session_id)
    return unless session_id.to_s.match?(/\A[0-9a-f-]{36}\z/)

    Dir[root.join("projects/*/#{session_id}.jsonl")].first
  end

  def self.abbreviate(path)
    path.to_s.sub(/\A#{Regexp.escape(Dir.home)}/, "~")
  end
end
