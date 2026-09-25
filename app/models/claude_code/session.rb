# A live Claude Code session, from ~/.claude/sessions/<pid>.json plus its transcript.
class ClaudeCode::Session
  STATUSES = { "busy" => "busy", "idle" => "idle", "waiting" => "blocked", "blocked" => "blocked" }.freeze
  SUBAGENT_LIMIT = 8
  SUBAGENT_WINDOW = 24.hours
  RUNNING_WINDOW = 90.seconds
  LARGE_CONTEXT = 200_000

  def self.live
    Dir[ClaudeCode.root.join("sessions/*.json")].filter_map { from_file(it) }.select(&:alive?).sort_by(&:started_at).reverse
  end

  # Ends the session's process, and with an Echo run everything it started.
  def self.end_session(id)
    session = find(id) or return false
    SpawnedAgent.tag_for(session.pid) ? ClaudeCode::Headless.stop(session.pid) : Process.kill("TERM", session.pid)
    true
  rescue Errno::ESRCH
    true
  end

  def self.find(id)
    live.find { it.id == id }
  end

  def self.from_file(path)
    new(JSON.parse(File.read(path)))
  rescue JSON::ParserError, Errno::ENOENT
    nil
  end

  def initialize(registry)
    @registry = registry
  end

  def id = @registry["sessionId"]
  def pid = @registry["pid"].to_i
  def started_at = Time.zone.at(@registry["startedAt"].to_i / 1000.0)

  def alive?
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  rescue Errno::EPERM
    true
  end

  def transcript
    return @transcript if defined?(@transcript)

    @transcript = transcript_path&.then { ClaudeCode::Transcript.for(it) }
  end

  def to_agent
    # Hooks know when a session is blocked on you; the registry doesn't.
    signal = SessionSignal.find_by(session_id: id)
    needs = signal&.needs
    status = needs ? "blocked" : STATUSES.fetch(@registry["status"], "idle")

    {
      id:, name: transcript&.custom_title || handle, handle:, renamed: transcript&.custom_title.present?, cwd: abbreviate(@registry["cwd"]),
      terminal_unavailable: ClaudeCode::Focus.unavailable_reason(pid),
      kind: "yours", task: SpawnedAgent.tag_for(pid), status:, branch: transcript&.git_branch,
      model: humanize_model(transcript&.model),
      started: started_at, active: last_active_at,
      tokens_today: tokens_since(Time.current.beginning_of_day), tokens_total: tokens_since(Time.zone.at(0)),
      context_percent:, turns: transcript&.turns,
      hourly_tokens: transcript&.hourly_tokens || Array.new(12, 0),
      title: transcript&.title, summary: transcript&.summary,
      last_prompt: transcript&.last_prompt&.truncate(4_000), last_reply: transcript&.last_reply&.truncate(8_000),
      needs: needs || (status == "blocked" ? "Waiting for your input" : nil), needs_at: needs ? signal.needs_at : nil,
      loops:, subagents:, jobs: []
    }
  end

  def transcript_path
    ClaudeCode.transcript_path(id)
  end

  # Claude Code's own short name for the session, e.g. "projects-f4".
  def handle = @registry["name"] || id.first(8)

  # Tokens aren't tied to a loop, so each carries what its session has used since
  # it started, which is mostly the loop's own work when a session is looping.
  def loops
    Array(transcript&.active_loops).map { it.merge(session_tokens_since_start: it[:started_at] ? tokens_since(it[:started_at]) : nil) }
  end

  private

  def session_dir
    transcript_path&.delete_suffix(".jsonl")
  end

  def last_active_at
    [ transcript&.last_activity_at, Time.zone.at(@registry["updatedAt"].to_i / 1000.0) ].compact.max
  end

  # The window size isn't recorded, so anything past 200k must be a 1M-context model.
  def context_percent
    tokens = transcript&.context_tokens or return
    (tokens * 100.0 / (tokens > LARGE_CONTEXT ? 1_000_000 : LARGE_CONTEXT)).round
  end

  def tokens_since(time)
    ([ transcript ] + subagent_transcripts.values).compact.sum { it.tokens_since(time) }
  end

  def subagent_transcripts
    @subagent_transcripts ||= Dir["#{session_dir}/subagents/agent-*.jsonl"].to_h { [ it, ClaudeCode::Transcript.for(it) ] }
  end

  def subagents
    return [] unless session_dir

    subagent_transcripts
      .filter_map { |path, t| t && subagent(path, t) }
      .select { it[:active] > SUBAGENT_WINDOW.ago }
      .sort_by { -it[:active].to_i }
      .first(SUBAGENT_LIMIT)
  end

  def subagent(path, transcript)
    meta = JSON.parse(File.read(path.sub(/\.jsonl\z/, ".meta.json"))) rescue {}
    active = transcript.last_activity_at || File.mtime(path)

    {
      type: meta["agentType"] || "agent", name: meta["description"],
      status: File.mtime(path) > RUNNING_WINDOW.ago ? "running" : "done",
      result: (transcript.last_reply || meta["description"]).to_s.squish.truncate(200), active:
    }
  end

  # "claude-opus-5-5" → "Opus 5.5", "claude-haiku-4-5-20251001" → "Haiku 4.5"
  def humanize_model(model)
    return "unknown" if model.blank?

    family, *version = model.delete_prefix("claude-").sub(/-\d{8}\z/, "").split("-")
    [ family.capitalize, version.join(".").presence ].compact.join(" ")
  end

  def abbreviate(path) = ClaudeCode.abbreviate(path)
end
