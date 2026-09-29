require "test_helper"

class ConnectionCheckTest < ActiveSupport::TestCase
  test "a failed check keeps the last good status for a while, then gives in" do
    with_cache do
      assert_equal "dana", ConnectionCheck.fetch("gh") { { connected: true, login: "dana" } }[:login]

      Rails.cache.delete("gh")
      assert ConnectionCheck.fetch("gh") { { connected: false } }[:connected], "no network just after waking isn't a logout"

      travel ConnectionCheck::GRACE + 1.minute do
        Rails.cache.delete("gh")
        assert_not ConnectionCheck.fetch("gh") { { connected: false } }[:connected]
      end
    end
  end

  test "logging out through Echo isn't smoothed over" do
    with_cache do
      ConnectionCheck.fetch("acli") { { connected: true } }
      ConnectionCheck.forget("acli")
      assert_not ConnectionCheck.fetch("acli") { { connected: false } }[:connected]
    end
  end

  def with_cache(&)
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new, &)
  end
end
