# A counter that goes up whenever something a page shows may have changed (a
# hook event, a finished sync), so open pages can refresh right away.
module Changes
  KEY = "echo-changes".freeze

  def self.bump = Rails.cache.increment(KEY, 1, initial: 1)
  def self.version = Rails.cache.read(KEY, raw: true).to_i
end
