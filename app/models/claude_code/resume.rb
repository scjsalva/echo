require "shellwords"

# Picks an ended session back up with `claude --resume`, the command Claude Code
# prints when a session exits.
module ClaudeCode::Resume
  class Error < StandardError; end

  def self.command(session_id, cwd)
    resume = "claude --resume #{Shellwords.escape(session_id)}"
    cwd.present? ? "cd #{Shellwords.escape(cwd)} && #{resume}" : resume
  end

  def self.open_in_terminal(session_id)
    path = ClaudeCode.transcript_path(session_id) or raise Error, "No transcript for this session"
    raise Error, "This session is still running" if ClaudeCode::Session.live.any? { it.id == session_id }

    TerminalApp.run(command(session_id, ClaudeCode::Transcript.for(path)&.cwd))
  rescue TerminalApp::Error => e
    raise Error, e.message
  end
end
