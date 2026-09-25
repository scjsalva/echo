class Api::FocusController < ApplicationController
  def create
    ClaudeCode::Focus.focus(params[:agent_id])
    head :no_content
  rescue ClaudeCode::Focus::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
