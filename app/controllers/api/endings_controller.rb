# Ends a live session, as if you'd quit it in its terminal.
class Api::EndingsController < ApplicationController
  def create
    ClaudeCode::Session.end_session(params[:agent_id]) ? head(:no_content) : render(json: { error: "This session isn't running" }, status: :not_found)
  end
end
