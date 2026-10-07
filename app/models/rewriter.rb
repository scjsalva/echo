# Rewrites a comment or summary with your own skill for it (Settings → Claude →
# Skills → Rewrite in your words), e.g. so a finding reads as if you wrote it.
module Rewriter
  class Error < StandardError; end

  MODEL = "sonnet"
  TIMEOUT = 3.minutes
  RULES = <<~RULES.squish.freeze
    Rewrite the text you're given, following the skill above. Reply with the rewritten text only, as it should be
    posted: no preamble, no notes, and not wrapped in a quote or a code block. Keep any code blocks that are part of the
    text itself, such as a suggestion block.
  RULES

  def self.skill = Skills.for("rewrite")

  def self.rewrite(text)
    chosen = skill or raise Error, "Choose a skill for Rewrite in your words in Settings first"
    raise Error, "Nothing to rewrite" if text.to_s.strip.empty?

    # Run from tmp/ with no tools, MCP, hooks or saved session: it only works on the text it's given.
    command = [ "claude", "-p", "--model", MODEL, "--no-session-persistence", "--tools", "", "--strict-mcp-config",
      "--setting-sources", "project", "--system-prompt", "#{chosen.instructions}\n\n## Echo's rules\n\n#{RULES}" ]
    output, status = ClaudeCode::Headless.run(command, input: text, chdir: Rails.root.join("tmp"), timeout: TIMEOUT, purpose: "rewrite")
    raise Error, output.strip.truncate(300) unless status.success?

    unwrap(output.strip)
  rescue ClaudeCode::Headless::Timeout
    raise Error, "Claude took longer than #{TIMEOUT.inspect}"
  rescue Errno::ENOENT
    raise Error, "The claude command isn't on PATH"
  end

  # In case the skill's habit of quoting its draft wins anyway: a whole-reply quote or fence comes off.
  def self.unwrap(text)
    if (fenced = text.match(/\A```(?!suggestion)[\w-]*\n(.*)\n```\z/m)) then fenced[1].strip
    elsif text.lines.all? { it.start_with?(">") || it.strip.empty? } then text.gsub(/^> ?/, "").strip
    else text
    end
  end

  private_class_method :unwrap
end
