# Keeps each added board's tickets: one search per board, through its saved
# filter, for what's open plus anything finished in the last 14 days. A scrum
# board's tickets also note their sprint. Searches can't return the sprint field,
# so each of its current and next few sprints is searched for its tickets.
# Searches can't return a ticket's parent either: one finds which tickets have
# one, and each of those is then looked at, remembered for a while, to see whose.
class Jira::BoardSync
  FIELDS = "key,summary,status,issuetype,priority,assignee".freeze
  RECENT = "(statusCategory != Done OR updated >= -14d)".freeze
  # acli answers `--fields key` with empty entries, so ask for a second field when only keys are wanted.
  KEYS_ONLY = "key,status".freeze
  FUTURE_SPRINTS = 3
  PARENT_FOR = 6.hours
  # Parents looked up per sync, a few at a time, so a big board fills in over a few minutes.
  PARENT_LOOKUPS = 40
  THREADS = 4

  def run
    Jira::Boards.all.each { sync(it) }
  end

  private

  def sync(board)
    jql = "filter = #{board[:filter_id]} AND #{RECENT} ORDER BY Rank ASC"
    issues = Array(Jira::Cli.run("workitem", "search", "--jql", jql, "--paginate", "--fields", FIELDS, json: true))
    now = Time.current
    sprint_of = sprints(board)
    parent_of = parents(board)
    rows = issues.each_with_index.map do |issue, position|
      data = shape(issue).merge(sprint_of[issue["key"]] || {}).merge(parent_of[issue["key"]] || {})
      { board_id: board[:id], key: issue["key"], position:, data:, created_at: now, updated_at: now }
    end
    JiraBoardTicket.upsert_all(rows, unique_by: %i[board_id key]) if rows.any?
    JiraBoardTicket.where(board_id: board[:id]).where.not(key: rows.pluck(:key)).delete_all
    Jira::Boards.learn_statuses(board[:id], rows.map { { name: it[:data][:status], category: it[:data][:status_category] } })
  end

  # Which sprint each ticket is in, for a scrum board: { "APP-1" => { sprint: "Sprint 9", sprint_state: "active" } }.
  def sprints(board)
    type = board[:type] || Jira::Cli.run("board", "view", "--id", board[:id].to_s, json: true)["type"]
    Jira::Boards.update_type(board[:id], type) unless board[:type]
    return {} unless type == "scrum"

    listed = Array(Jira::Cli.run("board", "list-sprints", "--id", board[:id].to_s, "--state", "active,future", json: true)["sprints"])
    current = listed.select { it["state"] == "active" } + listed.select { it["state"] == "future" }.first(FUTURE_SPRINTS)
    Jira::Boards.record_sprints(board[:id], current.map { { id: it["id"], name: it["name"], state: it["state"] } })
    current.each_with_object({}) do |sprint, found|
      keys = Array(Jira::Cli.run("workitem", "search", "--jql", "filter = #{board[:filter_id]} AND sprint = #{sprint['id']}", "--paginate", "--fields", KEYS_ONLY, json: true))
      keys.each { found[it["key"]] ||= { sprint: sprint["name"], sprint_state: sprint["state"] } }
    end
  end

  # Each child ticket's parent: { "APP-2" => { parent_key: "APP-1", parent_title:, parent_type:, parent_status:, parent_checked_at: } }.
  def parents(board)
    children = Array(Jira::Cli.run("workitem", "search", "--jql", "filter = #{board[:filter_id]} AND parent is not EMPTY AND #{RECENT}",
      "--paginate", "--fields", KEYS_ONLY, json: true)).map { it["key"] }
    known = JiraBoardTicket.where(board_id: board[:id], key: children).to_h { [ it.key, it.data.slice(*PARENT_KEYS) ] }
    stale = children.select { (known[it]&.dig("parent_checked_at")&.then { Time.zone.parse(it) } || Time.at(0)) < PARENT_FOR.ago }
    found = stale.first(PARENT_LOOKUPS).each_slice(THREADS).flat_map { |slice| slice.map { |key| Thread.new { [ key, parent(key) ] } }.map(&:value) }
    known.slice(*children).merge(found.to_h.compact).transform_values(&:symbolize_keys)
  end

  PARENT_KEYS = %w[parent_key parent_title parent_type parent_status parent_checked_at].freeze

  def parent(key)
    parent = Jira::Cli.run("workitem", "view", key, "--fields", "parent", json: true).dig("fields", "parent") or return
    { "parent_key" => parent["key"], "parent_title" => parent.dig("fields", "summary"), "parent_type" => parent.dig("fields", "issuetype", "name"),
      "parent_status" => parent.dig("fields", "status", "name"), "parent_checked_at" => Time.current.iso8601 }
  rescue Jira::Cli::Error
    nil
  end

  def shape(issue)
    fields = issue["fields"] || {}
    { key: issue["key"], title: fields["summary"], type: fields.dig("issuetype", "name"), subtask: fields.dig("issuetype", "subtask") || false,
      status: fields.dig("status", "name"),
      status_category: fields.dig("status", "statusCategory", "key"), priority: fields.dig("priority", "name"),
      assignee: fields.dig("assignee", "displayName"), assignee_id: fields.dig("assignee", "accountId") }
  end
end
