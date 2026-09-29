require "open3"

# The zone that "today" and every day-based figure use. Automatic by default:
# it follows the computer's time zone, read on each request so it tracks
# changes (travel, a new setting) without restarting Echo.
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
    return windows_zone || ENV["TZ"].presence || "UTC" if Platform.windows?

    File.readlink("/etc/localtime")[%r{zoneinfo/(.+)\z}, 1] || ENV["TZ"].presence || "UTC"
  rescue SystemCallError
    ENV["TZ"].presence || "UTC"
  end

  # Windows names zones its own way ("Singapore Standard Time"); most match a
  # Rails name once " Standard Time" is dropped. Failing that, the zone with
  # the computer's current UTC offset.
  def self.windows_zone
    output, status = Open3.capture2("tzutil", "/g")
    name = output.strip.delete_suffix(" Standard Time") if status.success?
    zone = (ActiveSupport::TimeZone[name] if name.present?) || ActiveSupport::TimeZone.all.find { it.now.utc_offset == Time.now.utc_offset }
    zone&.tzinfo&.name
  rescue SystemCallError
    nil
  end

  def self.options
    ActiveSupport::TimeZone.all.uniq { it.tzinfo.name }.map { { value: it.tzinfo.name, label: it.to_s } }
  end

  def self.props
    { preference:, detected:, current: current.tzinfo.name, options: }
  end
end
