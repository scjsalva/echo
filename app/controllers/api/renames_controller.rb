# Names a session with Claude Code's own /rename, so the name lives on the
# session (and survives resuming it) rather than only in Echo.
class Api::RenamesController < ApplicationController
  MAX_LENGTH = 80

  def create
    name = params[:name].to_s.squish.first(MAX_LENGTH)
    return render(json: { error: "Give the agent a name" }, status: :unprocessable_content) if name.blank?

    ClaudeCode::Focus.type(params[:agent_id], "/rename #{name}")
    head :no_content
  rescue ClaudeCode::Focus::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
