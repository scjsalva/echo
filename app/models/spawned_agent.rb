# A headless Claude run Echo started, e.g. for an AI review. Recorded by pid so
# the Agents page can say what it's for, and so leftovers can be ended.
class SpawnedAgent < ApplicationRecord
  PURPOSES = { "ai_review" => "AI review", "review_question" => "Review question", "summary" => "Summary" }.freeze

  validates :purpose, inclusion: { in: PURPOSES.keys }

  scope :running, -> { where(ended_at: nil) }

  def self.tag_for(pid)
    agent = running.where(pid:).order(:created_at).last or return
    { purpose: agent.purpose, label: PURPOSES[agent.purpose], ref: agent.ref }
  end

  def label = PURPOSES[purpose]
end
