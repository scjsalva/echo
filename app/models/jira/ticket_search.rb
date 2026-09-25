# Live Jira searches through acli, 10 results per page behind "Load more": your
# finished tickets, or any ticket when a search finds nothing locally. The search
# can't return an updated date to page by, so each page skips the keys already shown.
module Jira::TicketSearch
  PAGE_SIZE = 10
  SCOPES = {
    "assigned" => "assignee = currentUser()", "watching" => "watcher = currentUser()", "reported" => "reporter = currentUser()",
    "all" => "(assignee = currentUser() OR watcher = currentUser() OR reporter = currentUser())"
  }.freeze
  KEY = /\A[A-Z][A-Z0-9_]+-\d+\z/

  # `scope` limits to your tickets (see SCOPES); nil searches all of Jira.
  def self.page(site:, scope: nil, done: false, type: nil, query: nil, seen: [])
    jql = []
    jql << SCOPES.fetch(scope) if scope
    jql << "statusCategory = Done" if done
    jql << "issuetype = #{quote(type)}" if type.present?
    jql << text_match(query.strip) if query.present?
    seen = Array(seen).grep(KEY)
    jql << "key NOT IN (#{seen.join(',')})" if seen.any?
    raise ArgumentError, "A search needs a scope or a query" if jql.empty?

    results = Jira::Cli.run("workitem", "search", "--jql", "#{jql.join(' AND ')} ORDER BY updated DESC", "--limit", (PAGE_SIZE + 1).to_s,
      "--fields", "key,summary,status,issuetype,priority,assignee,reporter", json: true)
    { items: results.first(PAGE_SIZE).map { ticket(it, site:) }, more: results.size > PAGE_SIZE }
  end

  # A ticket key matches that ticket; anything else searches summary, description and comments.
  def self.text_match(query)
    query.upcase.match?(KEY) ? "key = #{query.upcase}" : "text ~ #{quote(query)}"
  end

  def self.quote(value) = %("#{value.to_s.gsub(/["\\]/, '')}")

  def self.ticket(result, site:)
    f = result["fields"] || {}
    category = f.dig("status", "statusCategory", "key")
    {
      key: result["key"], url: "https://#{site}/browse/#{result['key']}", title: f["summary"], type: f.dig("issuetype", "name"),
      status: f.dig("status", "name"),
      category: Jira::DashboardData.category(JiraTicket.new(status: f.dig("status", "name"), status_category: category)),
      priority: f.dig("priority", "name"), assignee: f.dig("assignee", "displayName"), reporter: f.dig("reporter", "displayName"),
      sprint: nil, description: nil, updated: nil, assigned_to_me: false
    }
  end

  private_class_method :text_match, :quote, :ticket
end
