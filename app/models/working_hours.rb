# When notifications may be sent. Outside these hours Echo stays quiet, and
# anything that came in waits until they start. A shift can run past midnight
# (e.g. 16:00 to 01:00): it counts as the day it starts on. Times are in Echo's
# time zone (Settings → General).
module WorkingHours
  SETTING = "working_hours".freeze
  DEFAULTS = { "enabled" => false, "days" => [ 1, 2, 3, 4, 5 ], "start" => "09:00", "end" => "17:00" }.freeze
  TIME = /\A([01]\d|2[0-3]):[0-5]\d\z/

  def self.preferences = DEFAULTS.merge(Setting[SETTING] ? JSON.parse(Setting[SETTING]) : {})

  def self.update(enabled: nil, days: nil, start: nil, finish: nil)
    prefs = preferences
    prefs["enabled"] = ActiveModel::Type::Boolean.new.cast(enabled) unless enabled.nil?
    if days
      days = Array(days).map(&:to_i).uniq.sort
      raise ArgumentError, "Days are 0 (Sunday) to 6 (Saturday)" unless days.all? { it.between?(0, 6) }

      prefs["days"] = days
    end
    { "start" => start, "end" => finish }.compact.each do |key, value|
      raise ArgumentError, "Times look like 09:00" unless value.to_s.match?(TIME)

      prefs[key] = value
    end
    Setting[SETTING] = prefs.to_json
  end

  def self.within?(time = Time.current)
    prefs = preferences
    return true unless prefs["enabled"]

    local = time.in_time_zone(LocalTimeZone.current)
    now, from, to = [ local.strftime("%H:%M"), prefs["start"], prefs["end"] ].map { minutes(it) }
    day = if from == to then local.wday # the whole day
    elsif from < to then (local.wday if now.between?(from, to - 1))
    elsif now >= from then local.wday # overnight shift, before midnight
    elsif now < to then (local.wday - 1) % 7 # overnight shift, after midnight: yesterday's
    end
    day.present? && prefs["days"].include?(day)
  end

  def self.props = preferences.merge("time_zone" => LocalTimeZone.current.tzinfo.name)

  def self.minutes(hhmm) = hhmm.split(":").then { |h, m| h.to_i * 60 + m.to_i }

  private_class_method :minutes
end
