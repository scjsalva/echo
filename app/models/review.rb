# A review you're writing on someone's PR. Comments stay staged in Echo until
# you commit them, and nothing reaches GitHub until you send the review.
class Review < ApplicationRecord
  has_many :comments, -> { order(:path, :line, :created_at) }, class_name: "ReviewComment", dependent: :destroy

  EVENTS = { "comment" => "COMMENT", "approve" => "APPROVE", "request_changes" => "REQUEST_CHANGES" }.freeze

  validates :status, inclusion: { in: %w[draft sent] }
  validates :ai_status, inclusion: { in: %w[idle running done failed] }

  # The review in progress on a PR, or a fresh one.
  def self.for(pr_key) = where(pr_key:, status: "draft").order(:created_at).last || create!(pr_key:)

  def repo = pr_key.split("#").first
  def number = pr_key.split("#").last.to_i

  # Checked on GitHub each time, since a PR can be merged while you review it.
  def merged? = Github::Cli.run("api", "repos/#{repo}/pulls/#{number}", json: true)["merged"] == true

  def to_props
    {
      id:, pr_key:, head_sha:, status:, ai_status:, ai_error:, ai_report:, sent_at:, github_url:,
      comments: comments.where.not(state: "removed").map(&:to_props)
    }
  end
end
