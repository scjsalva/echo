# Aggregates one session transcript (a JSONL file). Parsing is incremental:
# results are cached per path and only lines appended since the last read are
# parsed, so polling large transcripts stays cheap.
class ClaudeCode::Transcript
  LOOP_TOOLS = %w[Monitor ScheduleWakeup CronCreate CronDelete TaskStop].freeze
  NOTIFICATION = %r{<task-notification>.*?<task-id>(?<task_id>[^<]+)</task-id>(?<body>.*?)</task-notification>}m
  ENDED_STATUSES = %w[completed failed killed stopped].freeze
  # Usage is bucketed in 15-minute steps because every timezone offset is a
  # multiple of 15 minutes, so "today" starts on a bucket edge wherever you are.
  BUCKET = 15.minutes.to_i

  @cache = {}
  @lock = Mutex.new

  class << self
    def for(path)
      path = path.to_s
      stat = File.stat(path)
      @lock.synchronize do
        cached = @cache[path]
        cached = @cache[path] = new(path) if cached.nil? || stat.size < cached.offset
        cached.tap { it.read_new_lines(stat.size) }
      end
    rescue Errno::ENOENT
      nil
    end

    def clear_cache = @lock.synchronize { @cache.clear }

    # The conversation as a readable list, newest last. Read on demand rather than
    # cached, since only the transcript viewer and summaries need it.
    def messages(path, limit: 200)
      File.foreach(path).filter_map { message_from(JSON.parse(it)) rescue nil }.flatten.last(limit)
    rescue Errno::ENOENT
      []
    end

    private

    def message_from(entry)
      at = entry["timestamp"]
      content = entry.dig("message", "content")

      case entry["type"]
      when "user"
        text = content.is_a?(String) ? content : Array(content).filter_map { it["text"] if it["type"] == "text" }.join("\n")
        { role: "you", text:, at: } if text.present? && !entry["isMeta"] && !text.lstrip.start_with?("<")
      when "assistant"
        Array(content).filter_map do |block|
          case block["type"]
          when "text" then { role: "claude", text: block["text"], at: }
          when "tool_use" then { role: "tool", text: [ block["name"], tool_summary(block["input"]) ].compact.join(" · "), at: }
          end
        end
      end
    end

    def tool_summary(input)
      return unless input.is_a?(Hash)

      input.values_at("description", "command", "file_path", "pattern", "url", "prompt").compact.first.to_s.squish.truncate(160).presence
    end
  end

  attr_reader :offset, :title, :summary, :last_prompt, :last_prompt_at, :last_reply, :last_reply_at,
    :model, :context_tokens, :turns, :total_tokens, :last_activity_at, :cwd, :git_branch, :custom_title

  def initialize(path)
    @path = path
    @offset = 0
    @turns = 0
    @total_tokens = 0
    @tokens_by_bucket = Hash.new(0)
    @message_ids = Set.new
    @loops = {}
    @task_loops = {}
    @seen_events = Set.new
  end

  def read_new_lines(size)
    return if size == @offset

    File.open(@path) do |file|
      file.seek(@offset)
      file.each_line do |line|
        # A partial last line means Claude Code is mid-write; pick it up next time.
        break unless line.end_with?("\n")

        @offset += line.bytesize
        ingest(JSON.parse(line))
      rescue JSON::ParserError
        next
      end
    end
  end

  def tokens_since(time)
    floor = time.to_i / BUCKET
    @tokens_by_bucket.sum { |bucket, tokens| bucket >= floor ? tokens : 0 }
  end

  # Tokens per hour for the last `hours` hours, oldest first.
  def hourly_tokens(hours: 12, now: Time.current)
    per_hour = 1.hour / BUCKET
    current = now.to_i / BUCKET
    (current - hours * per_hour + 1..current).each_slice(per_hour).map { |slice| slice.sum { @tokens_by_bucket[it] } }
  end

  def active_loops(now: Time.current)
    @loops.values.reject { it[:ended] || expired?(it, now) }.map do |loop|
      loop = loop.merge(next_run_at: next_cron_run(loop[:cron], now)) if loop[:kind] == "cron"
      loop.except(:ended, :task_id, :cron_id)
    end
  end

  private

  def ingest(entry)
    at = parse_time(entry["timestamp"])
    @last_activity_at = at if at && (@last_activity_at.nil? || at > @last_activity_at)
    @cwd = entry["cwd"] if entry["cwd"]
    # Detached checkouts (common in worktrees) report "HEAD", which isn't a branch name.
    @git_branch = entry["gitBranch"] if entry["gitBranch"].present? && entry["gitBranch"] != "HEAD"

    case entry["type"]
    when "ai-title" then @title = entry["aiTitle"]
    # Set with /rename in Claude Code.
    when "custom-title" then @custom_title = entry["customTitle"].presence
    when "system" then @summary = entry["content"] if entry["subtype"] == "away_summary"
    when "assistant" then ingest_assistant(entry["message"] || {}, at)
    when "user" then ingest_user(entry, at)
    when "queue-operation" then ingest_notifications(entry["content"], at) if entry["operation"] == "enqueue"
    end
  end

  def ingest_assistant(message, at)
    @model = message["model"] if message["model"].present?
    record_usage(message, at)

    Array(message["content"]).each do |block|
      case block["type"]
      when "text"
        @last_reply = block["text"]
        @last_reply_at = at
      when "tool_use"
        track_loop_tool(block, at) if LOOP_TOOLS.include?(block["name"])
      end
    end
  end

  # Claude Code writes one line per content block and repeats the message's usage
  # on each, so usage is counted once per message id. Cache reads are left out:
  # they would otherwise count the whole context again on every turn.
  def record_usage(message, at)
    usage = message["usage"]
    return if usage.nil? || at.nil? || !@message_ids.add?(message["id"])

    tokens = usage.values_at("input_tokens", "cache_creation_input_tokens", "output_tokens").sum(&:to_i)
    @tokens_by_bucket[at.to_i / BUCKET] += tokens
    @total_tokens += tokens
    @context_tokens = usage.values_at("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens").sum(&:to_i)
  end

  def ingest_user(entry, at)
    content = entry.dig("message", "content")
    text = content.is_a?(String) ? content : Array(content).filter_map { it["text"] if it["type"] == "text" }.join("\n")

    if human_prompt?(entry, text)
      @turns += 1
      @last_prompt = text
      @last_prompt_at = at
    end

    ingest_notifications(text, at)
    Array(content).each { link_tool_result(it, entry["toolUseResult"]) if it.is_a?(Hash) && it["type"] == "tool_result" }
  end

  def human_prompt?(entry, text)
    return false if entry["isMeta"] || text.blank?

    kind = entry.dig("origin", "kind")
    kind ? kind == "human" : !text.lstrip.start_with?("<")
  end

  def track_loop_tool(block, at)
    input = block["input"] || {}

    case block["name"]
    when "Monitor"
      @loops[block["id"]] = {
        id: block["id"], kind: "monitor", description: input["description"].presence || "Monitor",
        started_at: at, expires_at: input["persistent"] ? nil : at && at + (input["timeout_ms"] || 300_000) / 1000.0,
        events: 0, last_event_at: nil
      }
    when "ScheduleWakeup"
      track_wakeup(input, at)
    when "CronCreate"
      @loops[block["id"]] = {
        id: block["id"], kind: "cron", description: input["prompt"].to_s.truncate(120), cron: input["cron"],
        started_at: at, recurring: input.fetch("recurring", true),
        events: 0, last_event_at: nil
      }
    when "CronDelete"
      @loops.each_value { it[:ended] = true if it[:cron_id] == input["id"] }
    when "TaskStop"
      @task_loops[input["task_id"] || input["shell_id"]]&.store(:ended, true)
    end
  end

  # /loop without an interval re-arms itself with ScheduleWakeup; treat the chain as one loop.
  def track_wakeup(input, at)
    loop = @loops["wakeup"] ||= { id: "wakeup", kind: "wakeup", started_at: at, events: 0, last_event_at: nil }
    return loop[:ended] = true if input["stop"]

    loop.merge!(
      description: input["prompt"].to_s.start_with?("<<") ? input["reason"] : input["prompt"].presence || input["reason"],
      every: input["delaySeconds"].to_i, next_run_at: at && at + input["delaySeconds"].to_i,
      ended: false, events: loop[:events] + 1, last_event_at: at
    )
  end

  def link_tool_result(block, tool_use_result)
    loop = @loops[block["tool_use_id"]] or return
    return unless tool_use_result.is_a?(Hash)

    if (task_id = tool_use_result["taskId"])
      loop[:task_id] = task_id
      @task_loops[task_id] = loop
    end
    loop[:cron_id] = tool_use_result["id"] if loop[:kind] == "cron"
  end

  def ingest_notifications(text, at)
    return unless text.is_a?(String) && text.include?("<task-notification>")

    text.scan(NOTIFICATION) do
      task_id, body = Regexp.last_match.values_at(:task_id, :body)
      loop = @task_loops[task_id] or next
      next unless @seen_events.add?(Digest::MD5.hexdigest("#{task_id}#{body}"))

      status = body[%r{<status>([^<]+)</status>}, 1]
      if ENDED_STATUSES.include?(status)
        loop[:ended] = true
      else
        loop[:events] += 1
        loop[:last_event_at] = at
      end
    end
  end

  def expired?(loop, now)
    return loop[:expires_at] <= now if loop[:expires_at]
    # A wakeup loop that missed its next run by a wide margin has stopped re-arming.
    return loop[:next_run_at] + 10.minutes < now if loop[:kind] == "wakeup" && loop[:next_run_at]

    false
  end

  def next_cron_run(cron, at)
    return if cron.blank?

    Fugit.parse_cron(cron)&.next_time(at)&.to_t
  rescue ArgumentError
    nil
  end

  def parse_time(value)
    value && Time.zone.parse(value)
  rescue ArgumentError
    nil
  end
end
