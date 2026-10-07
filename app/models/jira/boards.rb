# The Jira board you follow, set in Settings → Jira: one at a time, and how its
# statuses are ordered or hidden. The Atlassian CLI
# can't read a board's columns, so a board's statuses are the ones its tickets
# use, ordered by Jira's status category until you reorder them.
module Jira::Boards
  class Error < StandardError; end

  SETTING = "jira_boards".freeze
  CATEGORY_ORDER = %w[new indeterminate done].freeze

  def self.all = (Setting[SETTING] ? JSON.parse(Setting[SETTING]) : []).map { { sprints: [] }.merge(it.deep_symbolize_keys) }
  def self.find(id) = all.find { it[:id] == id.to_i }

  def self.search(name)
    boards = Jira::Cli.run("board", "search", "--name", name.to_s, "--limit", "20", json: true)
    added = all.map { it[:id] }
    Array(boards["values"]).reject { added.include?(it["id"]) }.map { { id: it["id"], name: it["name"], location: it["location"], type: it["type"] } }
  end

  # A board's tickets come from its saved filter, which Jira names "Filter for <board>".
  def self.add(id)
    raise Error, "Remove #{all.first[:name]} first: Echo follows one board" if all.any?

    board = Jira::Cli.run("board", "view", "--id", id.to_s, json: true)
    filter = Array(Jira::Cli.run("filter", "search", "--name", "Filter for #{board["name"]}", "--paginate", json: true))
      .find { it["name"].to_s.strip == "Filter for #{board['name']}".strip }
    raise Error, "Couldn't find the saved filter for #{board['name']}, so its tickets can't be read" unless filter

    save([ { id: board["id"], name: board["name"], location: board["location"], type: board["type"], filter_id: filter["id"].to_i,
      statuses: [], sprints: [] } ])
  end

  def self.remove(id)
    save(all.reject { it[:id] == id.to_i })
    JiraBoardTicket.where(board_id: id.to_i).delete_all
  end

  # The statuses in the order you set, each shown or hidden. Ones you didn't list keep their place at the end.
  def self.arrange(id, statuses)
    board = find(id) or raise Error, "No such board"
    wanted = statuses.map { it.to_h.symbolize_keys }
    known = board[:statuses].index_by { it[:name] }
    arranged = wanted.filter_map { |s| known[s[:name]]&.merge(hidden: ActiveModel::Type::Boolean.new.cast(s[:hidden]) || false) }
    update(id, statuses: arranged + board[:statuses].reject { |s| wanted.any? { it[:name] == s[:name] } })
  end

  # Adds statuses the board's tickets use that it hasn't seen yet, after the others of their category.
  def self.learn_statuses(id, found)
    board = find(id) or return
    statuses = board[:statuses].dup
    found.uniq { it[:name] }.reject { |s| statuses.any? { it[:name] == s[:name] } }.each do |status|
      rank = CATEGORY_ORDER.index(status[:category]) || 1
      at = statuses.rindex { (CATEGORY_ORDER.index(it[:category]) || 1) <= rank }
      # Jira keeps a Backlog off the board, on its own page, so it starts hidden here too.
      statuses.insert(at ? at + 1 : 0, { name: status[:name], category: status[:category], hidden: status[:name].match?(/\Abacklog\z/i) })
    end
    update(id, statuses:) if statuses != board[:statuses]
  end

  # Each status says which of Echo's groups it falls in, e.g. "todo", so the page can gather a board's to-do statuses into one column.
  def self.props = { boards: all.map { |b| b.merge(statuses: b[:statuses].map { it.merge(group: Jira::DashboardData.category_for(it[:name], it[:category])) }) } }

  # A scrum board's current and upcoming sprints, newest work first; a kanban board has none.
  def self.record_sprints(id, sprints) = update(id, sprints:)
  def self.update_type(id, type) = update(id, type:)

  def self.update(id, **fields) = save(all.map { it[:id] == id.to_i ? it.merge(fields) : it })
  def self.save(boards) = (Setting[SETTING] = boards.to_json)

  private_class_method :update, :save
end
