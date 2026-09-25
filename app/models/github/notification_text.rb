# What happened on a PR, in words, e.g. "dana approved your PR". The same
# wording as app/frontend/lib/githubNotifications.ts, for OS notifications.
module Github::NotificationText
  # `mine` is whether the PR is yours; when it isn't (or Echo can't tell), it's "the PR".
  def self.for(reason:, actor:, body:, mine: false)
    who = actor || "Someone"
    said = body.present? ? %(: "#{body}") : ""
    pr = mine ? "your PR" : "the PR"
    case reason
    when "review_requested" then "#{who} asked you to review"
    when "approved" then "#{who} approved #{pr}#{said}"
    when "reviewed" then "#{who} reviewed #{pr}#{said}"
    when "review_dismissed" then "#{who}'s review was dismissed"
    when "changes_requested" then "#{who} requested changes#{said}"
    when "changes_requested_other" then "#{who} requested changes on the PR#{said}"
    when "mention" then "#{who} mentioned you#{said}"
    when "team_mention" then "#{who} mentioned your team#{said}"
    when "assign" then "You were assigned to the PR"
    when "ci_activity" then "CI activity on the PR"
    when "merged" then actor ? "#{actor} merged it" : "It was merged"
    when "closed" then "It was closed"
    when "follow_up" then "#{who} pushed new commits after your review"
    when "ready_for_review" then "#{who}'s PR is ready for review"
    else
      return actor ? %(#{actor}: "#{body}") : %("#{body}") if body.present?

      "New activity on this PR"
    end
  end
end
