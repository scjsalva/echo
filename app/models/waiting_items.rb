# Things that are blocked on the user. Each item stays open until its clear rule
# is met on the source (or the user dismisses it), regardless of read state.
class WaitingItems
  GITHUB_REASONS = {
    "review_requested" => { label: "Review request", clears: "Clears when you submit a review." },
    "mention" => { label: "Mention", clears: "Clears when you comment on or review the PR." },
    "team_mention" => { label: "Team mention", clears: "Clears when you comment on or review the PR." },
    "changes_requested" => { label: "Changes requested", clears: "Clears when you push new commits or re-request review." }
  }.freeze

  JIRA_KINDS = {
    "mention" => { label: "Mention", clears: "Clears when you comment on the ticket." },
    "assigned" => { label: "Assigned", clears: "Clears when you move it out of To Do." }
  }.freeze

  def initialize(agents:, pull_requests:, github_notifications:, jira_tickets:, jira_notifications:, dismissed_keys:)
    @agents = agents
    @pull_requests = pull_requests.index_by { it[:key] }
    @github_notifications = github_notifications
    @jira_tickets = jira_tickets.index_by { it[:key] }
    @jira_notifications = jira_notifications
    @dismissed_keys = dismissed_keys
  end

  def all
    (agent_items + github_items + jira_items).sort_by { -it[:at].to_i }
  end

  private

  def agent_items
    @agents.select { it[:needs].present? }.map do |agent|
      item(
        # Each block (a new permission request) is its own item, so dismissing or
        # being notified about one doesn't cover the next.
        key: "agent-#{agent[:id]}-#{agent[:needs_at].to_i}", source: "agent", kind: "agent_blocked", label: "Agent",
        title: agent[:needs], actor: agent[:name], detail: nil, at: agent[:needs_at] || agent[:active],
        clears: "Clears when the agent is no longer blocked.", ref: { agent_id: agent[:id] }
      )
    end
  end

  def github_items
    @github_notifications.filter_map do |notification|
      rule = GITHUB_REASONS[notification[:reason]] or next
      # Mentions can be on PRs Echo doesn't track, so fall back to what the notification says.
      pr = @pull_requests[notification[:pr_key]] || { key: notification[:pr_key], title: notification[:title] }

      item(
        key: "github-#{notification[:id]}", source: "github", kind: notification[:reason], label: rule[:label],
        title: pr[:title], actor: notification[:actor], detail: notification[:body], at: notification[:at],
        clears: rule[:clears], resolution: notification[:resolution],
        ref: { pr_key: pr[:key], notification_id: notification[:id] }
      )
    end
  end

  def jira_items
    @jira_notifications.filter_map do |notification|
      rule = JIRA_KINDS[notification[:kind]] or next
      ticket = @jira_tickets[notification[:key]] or next

      item(
        key: "jira-#{notification[:id]}", source: "jira", kind: notification[:kind], label: rule[:label],
        title: "#{ticket[:key]} · #{ticket[:title]}", actor: notification[:actor], detail: notification[:body], at: notification[:at],
        clears: rule[:clears], resolution: notification[:resolution],
        ref: { ticket_key: ticket[:key], notification_id: notification[:id] }
      )
    end
  end

  def item(resolution: nil, **attrs)
    status = if @dismissed_keys.include?(attrs[:key]) then "dismissed"
    elsif resolution then "resolved"
    else "open"
    end

    attrs.reverse_merge(delivery_key: attrs[:key]).merge(status:, resolution:)
  end
end
