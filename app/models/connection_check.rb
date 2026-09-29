# A login check (gh or acli) that rides out a moment without network, e.g.
# just after the computer wakes: while a check fails, the last good status stands
# for a few minutes instead of saying you're logged out.
module ConnectionCheck
  CHECK_EVERY = 30.seconds
  GRACE = 10.minutes

  def self.fetch(key)
    Rails.cache.fetch(key, expires_in: CHECK_EVERY) do
      status = yield
      if status[:connected]
        Setting["#{key}-ok"] = status.to_json unless Setting["#{key}-ok"] == status.to_json
        Rails.cache.delete("#{key}-failing-since")
        status
      else
        last_good(key) || status
      end
    end
  end

  # Logging in or out through Echo is definite, so it starts from scratch.
  def self.forget(key)
    Rails.cache.delete(key)
    Rails.cache.delete("#{key}-failing-since")
    Setting["#{key}-ok"] = nil
  end

  def self.last_good(key)
    last = Setting["#{key}-ok"] or return
    failing_since = Rails.cache.fetch("#{key}-failing-since") { Time.current }
    JSON.parse(last, symbolize_names: true) if failing_since > GRACE.ago
  end

  private_class_method :last_good
end
