# Receives Claude Code hook events (see ClaudeCode::Hooks). They come from curl,
# not a browser, so there's no CSRF token; only requests from this machine count.
class Api::HooksController < ApplicationController
  skip_forgery_protection

  def create
    return head :forbidden unless request.local?

    if SessionSignal.record(JSON.parse(request.raw_post))
      Changes.bump
      NotifyJob.perform_later
    end
    head :no_content
  rescue JSON::ParserError
    head :bad_request
  end
end
