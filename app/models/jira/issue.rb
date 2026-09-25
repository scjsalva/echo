# One Jira work item as returned by `acli jira workitem view --json`.
class Jira::Issue
  # All regular fields, so custom ones like sprint come along whatever their id is on this site.
  FIELDS = "*navigable,comment".freeze

  Comment = Data.define(:id, :author_id, :author, :bot, :text, :created, :mentions_me)

  def initialize(json, me:)
    @json = json
    @fields = json["fields"] || {}
    @me = me
  end

  def key = @json["key"]
  def updated_at = Time.zone.parse(@fields["updated"].to_s)
  def status = @fields.dig("status", "name")

  def attributes
    {
      key:, title: @fields["summary"], issue_type: @fields.dig("issuetype", "name"), status:,
      status_category: @fields.dig("status", "statusCategory", "key"), priority: @fields.dig("priority", "name"),
      assignee: @fields.dig("assignee", "displayName"), assigned_to_me: @me.present? && @fields.dig("assignee", "accountId") == @me,
      reporter: @fields.dig("reporter", "displayName"), reported_by_me: @me.present? && @fields.dig("reporter", "accountId") == @me,
      watching: @fields.dig("watches", "isWatching") || false,
      sprint: active_sprint, description: Jira::Adf.to_text(@fields["description"]), jira_updated_at: updated_at
    }
  end

  def comments
    Array(@fields.dig("comment", "comments")).map do |c|
      Comment.new(
        id: c["id"], author_id: c.dig("author", "accountId"), author: c.dig("author", "displayName"),
        # Automation and CI post as "app" accounts; people are "atlassian".
        bot: c.dig("author", "accountType") == "app",
        text: Jira::Adf.to_text(c["body"]), created: Time.zone.parse(c["created"].to_s), mentions_me: Jira::Adf.mentions?(c["body"], @me)
      )
    end
  end

  private

  def active_sprint = Jira::Issue.sprint(@fields)

  # Sprints live in a custom field whose id differs per Jira site, so find it by
  # its shape (a list of sprints with a board and a state) and prefer the active one.
  def self.sprint(fields)
    sprints = fields.values.find { |value| value.is_a?(Array) && value.first.is_a?(Hash) && value.first.key?("boardId") && value.first.key?("state") }
    (Array(sprints).find { it["state"] == "active" } || Array(sprints).last)&.dig("name")
  end
end
