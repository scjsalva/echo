class Api::SummariesController < ApplicationController
  def create
    render json: camelize(ClaudeCode::Summary.for(params[:agent_id]))
  rescue ClaudeCode::Summary::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
