# Loads the sample dashboard used by tests, resolving durations like "4m" (ago)
# and "in 3m" (ahead) relative to now.
class SampleData
  PATH = Rails.root.join("test/fixtures/files/dashboard_sample.yml")
  TIME_KEYS = %w[started active started_at last_event_at next_run_at expires_at opened updated at].freeze
  UNITS = { "s" => 1.second, "m" => 1.minute, "h" => 1.hour, "d" => 1.day }.freeze

  def self.load(now: Time.current)
    resolve_times(YAML.load_file(PATH), now).with_indifferent_access
  end

  def self.resolve_times(value, now)
    case value
    when Hash then value.to_h { |key, v| [ key, TIME_KEYS.include?(key) ? ago(v, now) : resolve_times(v, now) ] }
    when Array then value.map { |v| resolve_times(v, now) }
    else value
    end
  end

  def self.ago(duration, now)
    ahead, amount, unit = duration.to_s.match(/\A(in )?(\d+)([smhd])\z/)&.captures
    raise ArgumentError, "invalid duration #{duration.inspect}" unless amount

    offset = amount.to_i * UNITS.fetch(unit)
    ahead ? now + offset : now - offset
  end

  private_class_method :resolve_times, :ago
end
