require "test_helper"

class AwayControllerTest < ActionDispatch::IntegrationTest
  test "goes away for the rest of today, then comes back" do
    patch "/api/away", params: { choice: "today" }, as: :json
    assert_response :success
    assert Away.active?
    assert_equal Away.until, Time.zone.parse(response.parsed_body["until"])

    delete "/api/away", as: :json
    assert_response :success
    assert_not Away.active?
  end

  test "explains a date that isn't after today" do
    patch "/api/away", params: { choice: "date", date: Date.yesterday.to_s }, as: :json

    assert_response :unprocessable_content
    assert_equal "Pick a date after today", response.parsed_body["error"]
  end
end
