class Api::ResumesController < ApplicationController
  def create
    ClaudeCode::Resume.open_in_terminal(params[:ended_session_id])
    head :no_content
  rescue ClaudeCode::Resume::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
