# Keeps the computer from going to sleep when idle while there's work going:
# while agents are working, or during your working hours. Off unless you turn
# it on. The screen still turns off and locks as usual (see SleepBlocker).
# The watchdog checks every few seconds and holds or lets go accordingly.
module KeepAwake
  SETTING = "keep_awake".freeze
  MODES = %w[off agents working_hours].freeze
  # After the last agent goes idle, in case another turn follows straight on.
  GRACE = 2.minutes
  BUSY_AT = "keep-awake-busy-at".freeze
  REASON = "keep-awake-reason".freeze

  def self.mode = Setting[SETTING].presence_in(MODES) || "off"

  def self.mode=(value)
    raise ArgumentError, "Keep awake is one of #{MODES.to_sentence(last_word_connector: ' or ')}" unless MODES.include?(value)

    Setting[SETTING] = value == "off" ? nil : value
    update
  end

  # Why the computer should stay awake right now, or nil.
  def self.reason
    case mode
    when "agents"
      working = ClaudeCode::Session.live.count(&:working?)
      if working.positive?
        Rails.cache.write(BUSY_AT, Time.current)
        "#{working} #{'agent'.pluralize(working)} working"
      elsif (busy_at = Rails.cache.read(BUSY_AT)) && busy_at > GRACE.ago
        "An agent was working a few minutes ago"
      end
    when "working_hours"
      "During your working hours" if WorkingHours.within?
    end
  end

  def self.update
    now = reason
    Rails.cache.write(REASON, now)
    now ? SleepBlocker.hold(now) : SleepBlocker.release
  end

  # What the header shows: the reason while it's holding, else nil.
  def self.current = (Rails.cache.read(REASON) if SleepBlocker.held?)

  def self.props = { mode:, available: SleepBlocker.available?, current:, working_hours_on: WorkingHours.preferences["enabled"] }
end
