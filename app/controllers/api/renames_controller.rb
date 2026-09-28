# Names a session with Claude Code's own /rename, so the name lives on the
# session (and survives resuming it) rather than only in Echo.
class Api::RenamesController < ApplicationController
  MAX_LENGTH = 80

  def create
    name = params[:name].to_s.squish.first(MAX_LENGTH)
    return render(json: { error: "Give the agent a name" }, status: :unprocessable_content) if name.blank?

    # Renaming types /rename into the session's terminal. While it's working or
    # waiting on you, that can land in the middle of what you're typing there and
    # send it, so only an idle session is renamed.
    status = ClaudeCode::Session.find(params[:agent_id])&.to_agent&.dig(:status)
    unless status.nil? || status == "idle"
      return render(json: { error: "It's in the middle of something. Rename it once it's idle." }, status: :conflict)
    end

    ClaudeCode::Focus.type(params[:agent_id], "/rename #{name}")
    head :no_content
  rescue ClaudeCode::Focus::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
