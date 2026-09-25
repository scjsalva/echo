# One comment on a line of a PR's diff: staged until you commit it, and only
# committed ones are sent with the review.
class ReviewComment < ApplicationRecord
  belongs_to :review

  STATES = %w[staged committed removed sent].freeze
  SIDES = %w[LEFT RIGHT].freeze

  validates :state, inclusion: { in: STATES }
  validates :side, inclusion: { in: SIDES }
  validates :author, inclusion: { in: %w[ai you] }
  validates :path, :body, presence: true
  validates :line, numericality: { only_integer: true, greater_than: 0 }

  def to_props = slice(:id, :path, :line, :side, :start_line, :body, :state, :author, :severity, :evidence, :notes, :asking)

  # What GitHub's create-review API expects for this comment.
  def to_github
    { path:, line:, side:, body: }.merge(start_line ? { start_line:, start_side: side } : {})
  end
end
