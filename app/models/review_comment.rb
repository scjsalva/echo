# One comment on a line of a PR's diff, or a reply to an earlier thread on GitHub
# (one with a thread_id): staged until you commit it, and only committed ones are
# sent with the review. A reply can also be sent on its own straight away.
class ReviewComment < ApplicationRecord
  belongs_to :review

  STATES = %w[staged committed removed sent].freeze
  SIDES = %w[LEFT RIGHT].freeze

  validates :state, inclusion: { in: STATES }
  validates :side, inclusion: { in: SIDES }
  validates :author, inclusion: { in: %w[ai you] }
  validates :path, presence: true
  # Yours can start empty when you ask Claude about a line first; only a comment
  # with something in it can be committed and sent.
  validates :body, presence: true, if: -> { author == "ai" || state.in?(%w[committed sent]) }
  validates :line, numericality: { only_integer: true, greater_than: 0 }

  scope :replies, -> { where.not(thread_id: nil) }
  scope :on_lines, -> { where(thread_id: nil) }

  def reply? = thread_id.present?

  def to_props = slice(:id, :path, :line, :side, :start_line, :body, :state, :author, :severity, :evidence, :notes, :asking, :thread_id)

  # What GitHub's create-review API expects for this comment.
  def to_github
    { path:, line:, side:, body: }.merge(start_line ? { start_line:, start_side: side } : {})
  end
end
