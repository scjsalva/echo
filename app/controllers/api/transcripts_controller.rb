class Api::TranscriptsController < ApplicationController
  def show
    path = ClaudeCode.transcript_path(params[:agent_id]) or return head :not_found

    render json: camelize(messages: ClaudeCode::Transcript.messages(path))
  end
end
