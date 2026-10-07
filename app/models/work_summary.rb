# Claude's short take on an unassigned To Do ticket, for Jira → Find me work: what
# it's about and what you'd do. Kept 14 days, and only rewritten when the ticket's
# words change, so the same ticket isn't paid for twice.
class WorkSummary < ApplicationRecord
  KEEP_FOR = 14.days

  scope :current, -> { where(generated_at: KEEP_FOR.ago..) }
end
