# Jira tickets and notifications from the local sync, shaped for the dashboard.
module Jira::DashboardData
  NOTIFICATION_WINDOW = 14.days
  NOTIFICATION_LIMIT = 100

  def self.tickets(site:)
    JiraTicket.order(jira_updated_at: :desc).map do |t|
      {
        key: t.key, url: "https://#{site}/browse/#{t.key}", title: t.title, type: t.issue_type, status: t.status,
        category: category(t), priority: t.priority, assignee: t.assignee, reporter: t.reporter, sprint: t.sprint,
        description: t.description, updated: t.jira_updated_at, assigned_to_me: t.assigned_to_me,
        watching: t.watching, reported_by_me: t.reported_by_me
      }
    end
  end

  # Tickets on the boards you added, once each however many boards it's on.
  def self.board_tickets(site:, me:)
    JiraBoardTicket.order(:board_id, :position).group_by(&:key).map do |key, rows|
      t = rows.first.data.symbolize_keys
      { key:, url: "https://#{site}/browse/#{key}", title: t[:title], type: t[:type], status: t[:status],
        category: category_for(t[:status], t[:status_category]), status_category: t[:status_category], priority: t[:priority],
        assignee: t[:assignee], reporter: nil, sprint: rows.filter_map { it.data["sprint"] }.first, description: nil, updated: nil,
        sprint_state: rows.filter_map { it.data["sprint_state"] }.first,
        subtask: t[:subtask] || false,
        parent: t[:parent_key] && { key: t[:parent_key], title: t[:parent_title], type: t[:parent_type], status: t[:parent_status] },
        assigned_to_me: me.present? && t[:assignee_id] == me, boards: rows.to_h { [ it.board_id, it.position ] } }
    end
  end

  # Recent notifications, plus anything still waiting on you however old it is.
  def self.notifications(site:)
    waiting = JiraNotification.where(resolved_at: nil, kind: WaitingItems::JIRA_KINDS.keys)
    recent = JiraNotification.where(occurred_at: NOTIFICATION_WINDOW.ago..).order(occurred_at: :desc).limit(NOTIFICATION_LIMIT)
    (recent.to_a | waiting.to_a).sort_by { -it.occurred_at.to_i }.map do |n|
      { id: n.external_id, kind: n.kind, key: n.ticket_key, url: "https://#{site}/browse/#{n.ticket_key}", actor: n.actor, body: n.body, at: n.occurred_at,
        unread: n.read_at.nil?, resolution: n.resolution }
    end
  end

  # Jira only has three status categories (to do, in progress, done), so the
  # workflow stages in between are told apart by status name. Anything else
  # Jira calls "in progress" comes after code review, e.g. Ready to Release.
  def self.category(ticket) = category_for(ticket.status, ticket.status_category)

  def self.category_for(status, status_category)
    case status
    when /reopen/i then "todo"
    when /under investigation|in development/i then "in_progress"
    when /code review/i then "code_review"
    else
      { "new" => "todo", "done" => "done" }.fetch(status_category, "post_development")
    end
  end
end
