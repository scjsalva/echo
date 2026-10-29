require "net/http"
require "open3"

# Images pasted into PRs and comments live at github.com/user-attachments/assets/…
# (or <owner>/<repo>/assets/…), which only load for someone logged in to GitHub.
# Echo asks GitHub for one image with your gh login and gets back a signed address,
# good for a few minutes, that loads without a login. The browser is sent there;
# the token itself never reaches the page.
module Github::Image
  ASSET = %r{\Ahttps://github\.com/(?:user-attachments/assets|[\w.-]+/[\w.-]+/assets/\d+)/[\w-]+\z}
  # Signed addresses last 5 minutes; reuse one for a little less.
  KEEP = 4.minutes

  def self.asset?(url) = url.to_s.match?(ASSET)

  def self.signed_url(url)
    return unless asset?(url)

    Rails.cache.fetch([ "github-image", url ], expires_in: KEEP, skip_nil: true) do
      uri = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
        http.head(uri.request_uri, "Authorization" => "Bearer #{token}")
      end
      response["location"] if response.is_a?(Net::HTTPRedirection)
    end
  rescue SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError
    nil
  end

  def self.token
    output, status = Open3.capture2("gh", "auth", "token")
    status.success? ? output.strip : ""
  rescue Errno::ENOENT
    ""
  end

  private_class_method :token
end
