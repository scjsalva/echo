# Everything readable on one ticket, fetched on demand when its panel opens.
# Only text comes back; attachments are listed by name and opened in Jira.
class Jira::TicketDetail
  CACHE_FOR = 1.minute
  # Custom fields Jira uses internally (rank, the development panel summary).
  INTERNAL_TEXT = /\A(\d+\|\S+|\{.*\})\z/m

  def self.fetch(key, site:)
    raise ArgumentError, "Invalid ticket key" unless key.to_s.match?(/\A[A-Z][A-Z0-9_]+-\d+\z/)

    Rails.cache.fetch([ "jira-ticket", key ], expires_in: CACHE_FOR) do
      new(Jira::Cli.run("workitem", "view", key, "--fields", "*all", json: true), site:).to_h
    end
  end

  def initialize(json, site:)
    @key = json["key"]
    @fields = json["fields"] || {}
    @site = site
  end

  def to_h
    {
      key: @key, url: url(@key), description: text(@fields["description"]), environment: text(@fields["environment"]),
      creator: name(@fields["creator"]), created: @fields["created"], updated: @fields["updated"], due: @fields["duedate"],
      resolution: @fields.dig("resolution", "name"), resolved: @fields["resolutiondate"],
      labels: Array(@fields["labels"]), components: names(@fields["components"]),
      fix_versions: names(@fields["fixVersions"]), affects_versions: names(@fields["versions"]),
      time_tracking: @fields["timetracking"].presence&.slice("originalEstimate", "remainingEstimate", "timeSpent"),
      parent: related(@fields["parent"]), subtasks: Array(@fields["subtasks"]).map { related(it) },
      links: Array(@fields["issuelinks"]).filter_map { link(it) },
      attachments: Array(@fields["attachment"]).map { attachment(it) },
      more_details: more_details,
      comments: Array(@fields.dig("comment", "comments")).map { comment(it) }.sort_by { it[:created].to_s }.reverse
    }
  end

  private

  def url(key) = "https://#{@site}/browse/#{key}"
  def text(adf) = adf.is_a?(Hash) ? Jira::Adf.to_text(adf).presence : adf.presence
  def name(user) = user&.dig("displayName")
  def names(items) = Array(items).filter_map { it["name"] }

  def related(issue)
    return unless issue

    { key: issue["key"], url: url(issue["key"]), title: issue.dig("fields", "summary"), status: issue.dig("fields", "status", "name") }
  end

  def link(link)
    issue = link["outwardIssue"] || link["inwardIssue"] or return
    relation = link["outwardIssue"] ? link.dig("type", "outward") : link.dig("type", "inward")
    related(issue).merge(relation:)
  end

  def attachment(file)
    { name: file["filename"], size: file["size"], type: file["mimeType"], author: name(file["author"]), created: file["created"] }
  end

  def comment(c)
    { id: c["id"], author: name(c["author"]), bot: c.dig("author", "accountType") == "app", created: c["created"], text: text(c["body"]) }
  end

  # Custom text fields, e.g. acceptance criteria. acli can't return field names,
  # so they're shown unlabelled, in field order.
  def more_details
    @fields.select { |id, value| id.start_with?("customfield_") && custom_text?(value) }
      .sort_by { |id, _| id.delete_prefix("customfield_").to_i }
      .filter_map { |_, value| text(value) }
  end

  def custom_text?(value)
    (value.is_a?(Hash) && value["type"] == "doc") || (value.is_a?(String) && value.present? && !value.match?(INTERNAL_TEXT) && !value.match?(/\A\d{4}-\d\d-\d\dT/))
  end
end
