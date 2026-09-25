# Echo is a console for Claude Code, so there's nothing to show without it.
Rails.application.config.after_initialize do
  next if Rails.env.test? || ClaudeCode.available?

  abort <<~MESSAGE
    Echo needs Claude Code, but #{ClaudeCode.root} doesn't exist.
    Install Claude Code and run `claude` once, or set CLAUDE_CONFIG_DIR if you keep its config elsewhere.
  MESSAGE
end
