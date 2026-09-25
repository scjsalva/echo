# The zone that "today" and every day-based figure use. Automatic by default:
# it follows the Mac's timezone, read on each request so it tracks changes
# (travel, a new setting) without restarting Echo.
module LocalTimeZone
  AUTOMATIC = "auto"
  SETTING = "time_zone"

  def self.current
    ActiveSupport::TimeZone[preference == AUTOMATIC ? detected : preference] || ActiveSupport::TimeZone["UTC"]
  end

  def self.preference = Setting[SETTING] || AUTOMATIC

  def self.preference=(name)
    raise ArgumentError, "Unknown time zone #{name.inspect}" unless name == AUTOMATIC || ActiveSupport::TimeZone[name]

    Setting[SETTING] = name == AUTOMATIC ? nil : name
  end

  def self.detected
    File.readlink("/etc/localtime")[%r{zoneinfo/(.+)\z}, 1] || ENV["TZ"].presence || "UTC"
  rescue SystemCallError
    ENV["TZ"].presence || "UTC"
  end

  def self.options
    ActiveSupport::TimeZone.all.uniq { it.tzinfo.name }.map { { value: it.tzinfo.name, label: it.to_s } }
  end

  def self.props
    { preference:, detected:, current: current.tzinfo.name, options: }
  end
end
