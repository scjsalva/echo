# A day off (or longer): Echo keeps syncing but sends no notifications, and
# what comes in meanwhile is never sent, so nothing stale arrives when you're
# back. Your own agents are the exception: you started them to hear back.
module Away
  SETTING = "away_until".freeze

  def self.until
    time = Setting[SETTING]&.then { Time.zone.parse(it) }
    time if time&.future?
  end

  def self.active? = self.until.present?

  # The rest of today: back when your next working day starts.
  def self.rest_of_today = WorkingHours.next_start(after: Time.current.in_time_zone(LocalTimeZone.current).tomorrow.beginning_of_day)

  # Off until a date: back when that day's working hours start.
  def self.until_date(date)
    day = LocalTimeZone.current.parse(date.to_s)&.beginning_of_day
    raise ArgumentError, "Pick a date after today" unless day&.future?

    WorkingHours.next_start(after: day)
  end

  def self.start(choice, date: nil)
    back = case choice
    when "today" then rest_of_today
    when "date" then until_date(date)
    else raise ArgumentError, "Away is for today or until a date"
    end
    Setting[SETTING] = back.iso8601
  end

  def self.stop = Setting[SETTING] = nil

  def self.props = { until: self.until&.iso8601, rest_of_today: rest_of_today.iso8601 }
end
