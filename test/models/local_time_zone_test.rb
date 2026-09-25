require "test_helper"

class LocalTimeZoneTest < ActiveSupport::TestCase
  test "follows the Mac's zone until the user picks one" do
    LocalTimeZone.stub(:detected, "Europe/London") do
      assert_equal "Europe/London", LocalTimeZone.current.tzinfo.name

      LocalTimeZone.preference = "Asia/Manila"
      assert_equal "Asia/Manila", LocalTimeZone.current.tzinfo.name

      LocalTimeZone.preference = LocalTimeZone::AUTOMATIC
      assert_equal "Europe/London", LocalTimeZone.current.tzinfo.name
      assert_nil Setting[LocalTimeZone::SETTING]
    end
  end

  test "rejects zones that don't exist" do
    assert_raises(ArgumentError) { LocalTimeZone.preference = "Mars/Olympus" }
  end

  test "falls back to UTC when the detected zone is unknown" do
    LocalTimeZone.stub(:detected, "Nowhere/Special") do
      assert_equal "Etc/UTC", LocalTimeZone.current.tzinfo.name
    end
  end
end
