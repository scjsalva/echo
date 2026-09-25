class Api::EndedSessionsController < ApplicationController
  def index
    live_ids = ClaudeCode::Session.live.map(&:id)
    render json: camelize(ClaudeCode::EndedSession.page(live_ids:, before: params[:before], query: params[:q]))
  end
end
