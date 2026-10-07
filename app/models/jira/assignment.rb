# Assigns one ticket to you, or takes you off it, then reads back who has it so
# the board and your tickets show the change before the next sync.
module Jira::Assignment
  def self.take(key) = change(key, "--assignee", "@me")
  def self.drop(key) = change(key, "--remove-assignee")

  def self.change(key, *how)
    Jira::Cli.run("workitem", "assign", "--key", key, *how, "--yes")
    assignee = Jira::Cli.run("workitem", "view", key, "--fields", "assignee", json: true).dig("fields", "assignee")
    me = Setting[Jira::Sync::ACCOUNT_ID]
    name, id = assignee&.values_at("displayName", "accountId")

    JiraBoardTicket.where(key:).find_each { it.update!(data: it.data.merge("assignee" => name, "assignee_id" => id)) }
    JiraTicket.where(key:).update_all(assignee: name, assigned_to_me: me.present? && id == me)
    Rails.cache.delete([ "jira-ticket", key ])
    Changes.bump
  end

  private_class_method :change
end
