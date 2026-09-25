# A background Claude Code job (~/.claude/jobs/<id>/state.json).
class ClaudeCode::Job
  WINDOW = 7.days
  STATUSES = { "blocked" => "blocked", "running" => "busy", "working" => "busy" }.freeze
  # A job in one of these has finished, so it's no longer a live agent.
  FINISHED = %w[done completed failed error cancelled canceled killed stopped exited].freeze

  def self.recent
    Dir[ClaudeCode.root.join("jobs/*/state.json")].filter_map { from_file(it) }
      .select { it[:active] > WINDOW.ago && !FINISHED.include?(it[:jobs].first[:state]) }
  end

  def self.from_file(path)
    state = JSON.parse(File.read(path))
    status = STATUSES.fetch(state["state"], "idle")
    active = Time.zone.parse(state["updatedAt"].to_s) || File.mtime(path)

    {
      id: "job-#{File.basename(File.dirname(path))}", name: state["name"].presence || "Background job",
      cwd: ClaudeCode.abbreviate(state["cwd"]), kind: "background", status:, model: "background",
      terminal_unavailable: "Background jobs don't run in a terminal window",
      started: Time.zone.parse(state["createdAt"].to_s) || active, active:,
      tokens_today: 0, tokens_total: state["tokens"].to_i, context_percent: nil, turns: nil, hourly_tokens: Array.new(12, 0),
      title: state["name"], summary: nil, last_prompt: state["intent"], last_reply: state["detail"],
      needs: status == "blocked" ? state["needs"].presence&.upcase_first : nil,
      loops: [], subagents: [], jobs: [ { state: state["state"], detail: state["detail"] } ]
    }
  rescue JSON::ParserError, Errno::ENOENT
    nil
  end
end
