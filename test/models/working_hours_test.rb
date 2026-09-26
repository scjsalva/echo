require "test_helper"

class WorkingHoursTest < ActiveSupport::TestCase
  def at(zone, text) = ActiveSupport::TimeZone[zone].parse(text)

  test "off means any time" do
    assert WorkingHours.within?(at("UTC", "2026-09-27 03:00"))
  end

  test "a day shift, e.g. 8am to 5pm in the UK on weekdays" do
    LocalTimeZone.preference = "Europe/London"
    WorkingHours.update(enabled: true, days: [ 1, 2, 3, 4, 5 ], start: "08:00", finish: "17:00")

    assert WorkingHours.within?(at("Europe/London", "2026-09-28 08:00")) # Monday
    assert_not WorkingHours.within?(at("Europe/London", "2026-09-28 17:00"))
    assert_not WorkingHours.within?(at("Europe/London", "2026-09-27 10:00")) # Sunday
  end

  test "a shift past midnight counts as the day it starts, e.g. 4pm to 1am in Manila" do
    LocalTimeZone.preference = "Asia/Manila"
    WorkingHours.update(enabled: true, days: [ 1, 2, 3, 4, 5 ], start: "16:00", finish: "01:00")

    assert WorkingHours.within?(at("Asia/Manila", "2026-09-28 16:00")) # Monday afternoon
    assert WorkingHours.within?(at("Asia/Manila", "2026-09-29 00:30")) # still Monday's shift
    assert_not WorkingHours.within?(at("Asia/Manila", "2026-09-29 01:00"))
    assert WorkingHours.within?(at("Asia/Manila", "2026-10-03 00:30")) # Saturday 00:30 is Friday's shift
    assert_not WorkingHours.within?(at("Asia/Manila", "2026-10-04 00:30")) # Sunday 00:30 is Saturday's
    assert_not WorkingHours.within?(at("Asia/Manila", "2026-09-28 12:00"))
  end

  test "times are in Echo's time zone, whatever the server's clock says" do
    LocalTimeZone.preference = "Asia/Manila"
    WorkingHours.update(enabled: true, days: (0..6).to_a, start: "16:00", finish: "01:00")

    assert WorkingHours.within?(at("UTC", "2026-09-28 08:30")) # 16:30 in Manila
  end

  test "rejects bad times and days" do
    assert_raises(ArgumentError) { WorkingHours.update(start: "25:00") }
    assert_raises(ArgumentError) { WorkingHours.update(days: [ 7 ]) }
  end
end
