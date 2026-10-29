require "test_helper"

class GithubImagesTest < ActionDispatch::IntegrationTest
  ASSET = "https://github.com/user-attachments/assets/b15d8e65-bea7-4469-b654-7bb960c7c2ea".freeze

  test "sends the browser to GitHub's signed address for a pasted image" do
    Github::Image.stub(:signed_url, ->(src) { "https://objects.example/x.png?sig=1" if src == ASSET }) do
      get "/api/github/image", params: { src: ASSET }
    end

    assert_redirected_to "https://objects.example/x.png?sig=1"
  end

  test "only asks GitHub about its own image addresses, so the login is never sent anywhere else" do
    assert Github::Image.asset?(ASSET)
    assert Github::Image.asset?("https://github.com/acme/app/assets/123/b15d8e65-bea7-4469-b654-7bb960c7c2ea")
    [ "https://evil.example/user-attachments/assets/x", "https://github.com.evil.example/user-attachments/assets/x",
      "https://github.com/user-attachments/assets/x/../../login", "http://github.com/user-attachments/assets/x" ].each do |src|
      assert_not Github::Image.asset?(src), src
    end

    get "/api/github/image", params: { src: "https://evil.example/x.png" }
    assert_response :not_found
  end
end
