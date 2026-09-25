# What happened on a ticket, in words, e.g. "dana moved it: To Do → Done". The
# same wording as app/frontend/lib/jiraNotifications.ts, for OS notifications.
module Jira::NotificationText
  def self.for(kind:, actor:, body:)
    said = body.present? ? %(: "#{body}") : ""
    case kind
    when "transition" then actor ? "#{actor} moved it: #{body}" : "Status moved: #{body}"
    when "assigned" then actor ? "#{actor} assigned it to you" : "Assigned to you"
    when "mention" then "#{actor || 'Someone'} mentioned you#{said}"
    else "#{actor || 'Someone'} commented#{said}"
    end
  end
end
