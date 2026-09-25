# The extra files and skills that go with every Claude run Echo starts.
class Api::ClaudeContextsController < ApplicationController
  def update
    ClaudeCode::Context.extras = params.permit(extras: %i[kind value repo]).fetch(:extras, [])
    render json: camelize(context: ClaudeCode::Context.settings_props(Github::Preferences.repos))
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
