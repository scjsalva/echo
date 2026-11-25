require "test_helper"

class AwayTest < ActiveSupport::TestCase
  setup { LocalTimeZone.preference = "Asia/Manila" }

  test "the rest of today ends when your next working day starts, so a Friday runs to Monday" do
    WorkingHours.update(enabled: true, days: [ 1, 2, 3, 4, 5 ], start: "16:00", finish: "01:00")

    travel_to(Time.find_zone("Asia/Manila").parse("2026-11-27 10:00")) do # Friday
      Away.start("today")
      assert_equal Time.find_zone("Asia/Manila").parse("2026-11-30 16:00"), Away.until
    end
  end

  test "without working hours, the rest of today ends at midnight" do
    travel_to(Time.find_zone("Asia/Manila").parse("2026-11-27 10:00")) do
      assert_equal Time.find_zone("Asia/Manila").parse("2026-11-28 00:00"), Time.zone.parse(Away.props[:rest_of_today])
    end
  end

  test "until a date runs to that day's working hours, and ends on its own" do
    WorkingHours.update(enabled: true, days: [ 1, 2, 3, 4, 5 ], start: "09:00", finish: "17:00")

    travel_to(Time.find_zone("Asia/Manila").parse("2026-11-25 12:00")) do
      Away.start("date", date: "2026-12-01")
      assert Away.active?
      assert_raises(ArgumentError) { Away.start("date", date: "2026-11-25") }
    end
    travel_to(Time.find_zone("Asia/Manila").parse("2026-12-01 09:00")) { assert_not Away.active? }
  end

  test "keep awake during working hours lets the computer sleep while you're away" do
    WorkingHours.update(enabled: true, days: (0..6).to_a, start: "00:00", finish: "00:00")
    KeepAwake.stub(:mode, "working_hours") do
      assert KeepAwake.reason
      Away.start("today")
      assert_nil KeepAwake.reason
    end
  end
end
