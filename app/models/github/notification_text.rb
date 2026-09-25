# What happened on a PR, in words, e.g. "dana approved your PR". The same
# wording as app/frontend/lib/githubNotifications.ts, for OS notifications.
module Github::NotificationText
  def self.for(reason:, actor:, body:)
    who = actor || "Someone"
    said = body.present? ? %(: "#{body}") : ""
    case reason
    when "review_requested" then "#{who} asked you to review"
    when "approved" then "#{who} approved your PR#{said}"
    when "reviewed" then "#{who} reviewed your PR#{said}"
    when "review_dismissed" then "#{who}'s review was dismissed"
    when "changes_requested" then "#{who} requested changes#{said}"
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
