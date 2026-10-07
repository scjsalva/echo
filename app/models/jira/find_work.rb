require "digest"

# Jira → Find me work: the unassigned tickets in your board's To Do column, each
# with Claude's summary of what it's about and what you'd do, and the best few to
# pick up first. Tokens go only where they're needed:
# - summaries are kept 14 days, and redone only when a ticket's words change;
# - Haiku writes them, several tickets to a call, from trimmed text with no tools;
# - Claude only runs when you ask (Find me work, or Refresh on one ticket).
module Jira::FindWork
  MODEL = "haiku"
  BATCH = 8
  TOP = 5
  READS_AT_ONCE = 6
  TIMEOUT = 5.minutes
  RUNNING = "find-work-running".freeze
  LAST_ERROR = "find-work-error".freeze
  PRIORITY = { "highest" => 1, "high" => 2, "medium" => 3, "low" => 4, "lowest" => 5 }.freeze
  SIZE = { "S" => 1, "M" => 2, "L" => 3 }.freeze
  BACKLOG = /\Abacklog\z/i
  TAGS = %w[data_correction frontend backend investigation customer_reported].freeze
  # Part of every fingerprint, so changing what Claude's asked for redoes the summaries once.
  PROMPT_VERSION = "2"
  # Support-desk tickets end with a list of attachment links; it says nothing about the work.
  BOILERPLATE = /\*{0,2}Attachments links from Service Desk Ticket\*{0,2}.*/mi
  SCHEMA = {
    type: "object", required: %w[tickets],
    properties: { tickets: { type: "array", items: {
      type: "object", required: %w[key summary expected size ready question tags],
      properties: { key: { type: "string" }, summary: { type: "string" }, expected: { type: "string" },
        size: { type: "string", enum: %w[S M L] }, ready: { type: "boolean" }, question: { type: "string" },
        tags: { type: "array", items: { type: "string", enum: TAGS } } }
    } } }
  }.freeze
  RULES = <<~RULES.squish.freeze
    You help a developer choose which ticket to pick up next. For each ticket below write: summary, one or two plain
    sentences on what it's about, from the user's side where you can; expected, one or two sentences on what the developer
    would do (the likely change, in plain words); size, S for a few hours, M for a day or two, L for more; ready, false
    only if something must be answered before anyone can start; question, that one open question, or an empty string;
    tags, any that fit: data_correction (fixing or backfilling records, a one-off script or migration, not a product
    change), frontend, backend (where the change mostly lives; both if it spans them), investigation (the cause must be
    found before anything can be fixed), customer_reported (raised by a customer, e.g. through support).
    Go only on the ticket's text: don't invent code details, and say so when the text is unclear. Be brief.
  RULES

  class Error < StandardError; end

  def self.running? = Rails.cache.read(RUNNING).present?

  # What the page shows: every candidate, with its summary when there's a current one, best first.
  def self.list
    tickets = candidates
    prune(tickets)
    summaries = WorkSummary.current.where(ticket_key: tickets.map { it[:key] }).index_by(&:ticket_key)
    rows = tickets.map { |t| row(t, summaries[t[:key]]) }.sort_by { rank(it) }
    { tickets: rows, top: TOP, running: running?, summarised: summaries.size, error: Rails.cache.read(LAST_ERROR) }
  end

  # Starts summarising the candidates that need it (or just `keys`), in the background.
  def self.find(keys = nil)
    return false if running?

    Rails.cache.write(RUNNING, true, expires_in: 15.minutes)
    Rails.cache.delete(LAST_ERROR)
    FindWorkJob.perform_later(keys)
    Changes.bump
    true
  end

  # Reads each ticket in full, then has Claude summarise only those whose words changed.
  def self.run(keys = nil)
    wanted = keys.presence&.to_set
    tickets = candidates.select { wanted.nil? || wanted.include?(it[:key]) }
    Rails.cache.delete_multi(tickets.map { [ "jira-ticket", it[:key] ] }) if wanted
    details = read(tickets)
    known = WorkSummary.current.where(ticket_key: details.keys).index_by(&:ticket_key)
    stale = details.select { |key, detail| known[key]&.fingerprint != fingerprint(detail) }
    details.each { |key, detail| known[key]&.update!(due: detail[:due]) }
    stale.each_slice(BATCH) { |batch| save(summarise(batch.to_h), batch.to_h) }
  ensure
    Rails.cache.delete(RUNNING)
    Changes.bump
  end

  # Unassigned tickets in the board's To Do column: not the Backlog, nor a status you hid.
  def self.candidates
    board = Jira::Boards.all.first or return []
    hidden = board[:statuses].select { it[:hidden] }.map { it[:name] }
    Dashboard.current.jira_props[:jira_tickets].select do |t|
      t[:boards]&.key?(board[:id]) && t[:category] == "todo" && t[:assignee].blank? && !t[:status].to_s.match?(BACKLOG) && !hidden.include?(t[:status])
    end
  end

  # A summary goes once its ticket isn't up for grabs: someone has it and it's moved on, or it's left the board.
  def self.prune(tickets)
    open = tickets.map { it[:key] }
    on_board = Dashboard.current.jira_props[:jira_tickets].select { it[:boards].present? }.index_by { it[:key] }
    gone = WorkSummary.where.not(ticket_key: open).pluck(:ticket_key).select do |key|
      t = on_board[key]
      t.nil? || (t[:assignee].present? && t[:category] != "todo")
    end
    WorkSummary.where(ticket_key: gone).delete_all
    WorkSummary.where(generated_at: ...WorkSummary::KEEP_FOR.ago).delete_all
  end

  def self.row(ticket, summary)
    ticket.slice(:key, :url, :title, :type, :status, :priority).merge(
      due: summary&.due, summary: summary&.summary, expected: summary&.expected, size: summary&.size,
      ready: summary&.ready, question: summary&.question.presence, tags: summary&.tags || [], summarised_at: summary&.generated_at
    )
  end

  # Best first: summarised and ready, then by priority, how soon it's due, and size. No AI involved.
  def self.rank(row)
    priority = PRIORITY[row[:priority].to_s.downcase] || row[:priority].to_s[/\AP(\d)\z/i, 1]&.to_i || 3
    [ row[:summary] ? 0 : 1, row[:ready] == false ? 1 : 0, priority, row[:due] || Date.new(9999), SIZE[row[:size]] || 2, row[:key] ]
  end

  def self.read(tickets)
    site = Jira::Connection.status[:site]
    tickets.each_slice(READS_AT_ONCE).flat_map do |slice|
      slice.map { |t| Thread.new { [ t[:key], read_one(t, site) ] } }.map(&:value)
    end.to_h.compact
  end

  # One ticket in full, or nothing when Jira won't say (it's then left for next time).
  def self.read_one(ticket, site)
    Jira::TicketDetail.fetch(ticket[:key], site:).merge(title: ticket[:title])
  rescue Jira::Cli::Error, ArgumentError
    nil
  end

  # The words a summary is written from, trimmed so Claude reads only what matters.
  def self.text(detail)
    description = detail[:description].to_s
    [ ("Raised through the support desk." if description.match?(BOILERPLATE)),
      description.sub(BOILERPLATE, "").strip.truncate(3_000),
      *detail[:more_details].map { it.to_s.truncate(1_500) },
      *detail[:comments].first(3).map { "#{it[:author]}: #{it[:text].to_s.truncate(500)}" } ].compact_blank
  end

  def self.fingerprint(detail) = Digest::SHA256.hexdigest([ PROMPT_VERSION, detail[:title], *text(detail) ].join("\n"))

  def self.summarise(batch)
    input = batch.map { |key, detail| "## #{key}: #{detail[:title]}\n\n#{text(detail).join("\n\n")}" }.join("\n\n---\n\n")
    command = [ "claude", "-p", "--model", MODEL, "--output-format", "json", "--json-schema", SCHEMA.to_json, "--no-session-persistence",
      "--tools", "", "--strict-mcp-config", "--setting-sources", "project", "--system-prompt", RULES ]
    output, status = ClaudeCode::Headless.run(command, input:, chdir: Rails.root.join("tmp"), timeout: TIMEOUT, purpose: "find_work")
    raise Error, output.strip.truncate(300) unless status.success?

    result = JSON.parse(output.lines.find { it.start_with?("{") } || "{}")
    Array(result.dig("structured_output", "tickets"))
  rescue ClaudeCode::Headless::Timeout
    raise Error, "Claude took longer than #{TIMEOUT.inspect}"
  rescue JSON::ParserError
    raise Error, "Claude's answer couldn't be read"
  end

  def self.save(answers, batch)
    answers.each do |a|
      detail = batch[a["key"]] or next
      WorkSummary.find_or_initialize_by(ticket_key: a["key"]).update!(
        summary: a["summary"], expected: a["expected"], size: a["size"], ready: a["ready"] != false, question: a["question"].presence,
        tags: Array(a["tags"]) & TAGS, fingerprint: fingerprint(detail), due: detail[:due], generated_at: Time.current
      )
    end
  end

  private_class_method :prune, :row, :rank, :read, :read_one, :text, :fingerprint, :summarise, :save
end
