# A review you're writing on someone's PR. Comments stay staged in Echo until
# you commit them, and nothing reaches GitHub until you send the review.
class Review < ApplicationRecord
  has_many :comments, -> { order(:path, :line, :created_at) }, class_name: "ReviewComment", dependent: :destroy

  EVENTS = { "comment" => "COMMENT", "approve" => "APPROVE", "request_changes" => "REQUEST_CHANGES" }.freeze

  validates :status, inclusion: { in: %w[draft sent] }
  validates :ai_status, inclusion: { in: %w[idle queued running done failed] }

  # How many AI reviews run at once; more wait their turn as "queued".
  LIMIT_SETTING = "ai_review_limit".freeze
  LIMIT_OPTIONS = (1..5).to_a.freeze
  LIMIT_DEFAULT = 3
  # Longer than any real run (checkout plus Claude's timeout), so a review still
  # "running" after this was interrupted, e.g. by a restart.
  STALE_AFTER = 35.minutes
  SLOT_LOCK = Rails.root.join("tmp/ai_review_slots.lock")

  def self.limit = (Setting[LIMIT_SETTING] || LIMIT_DEFAULT).to_i

  def self.limit=(value)
    raise ArgumentError, "Choose between #{LIMIT_OPTIONS.first} and #{LIMIT_OPTIONS.last}" unless LIMIT_OPTIONS.include?(value.to_i)

    Setting[LIMIT_SETTING] = value.to_i.to_s
  end

  def self.release_stale
    where(ai_status: "running", updated_at: ...STALE_AFTER.ago)
      .update_all(ai_status: "failed", ai_error: "The review was interrupted, e.g. by Echo restarting. Start it again.", updated_at: Time.current)
  end

  # Takes one of the limited slots, or says there's none free. A file lock makes
  # the check and the claim one step, even across job threads.
  def claim_slot
    File.open(SLOT_LOCK, File::RDWR | File::CREAT) do |lock|
      lock.flock(File::LOCK_EX)
      self.class.release_stale
      return false if self.class.where(ai_status: "running").where.not(id:).count >= self.class.limit

      update!(ai_status: "running")
    end
  end

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
