class Api::SettingsController < ApplicationController
  def update
    LocalTimeZone.preference = params[:time_zone] if params.key?(:time_zone)
    Review.limit = params[:ai_review_limit] if params.key?(:ai_review_limit)
    Notifier.update(desktop: params[:notify_desktop], scope: params[:notify_scope], sound: params[:notify_sound], types: params[:notify_types],
      reminder_minutes: params[:review_reminder_minutes])
    Github::Preferences.update(repos: params[:github_repos], team: params[:github_team])
    Github::LocalRepos.set(params.dig(:github_local_repo, :repo), params.dig(:github_local_repo, :path)) if params.key?(:github_local_repo)
    render json: camelize(time_zone: LocalTimeZone.props.except(:options), notifications: Notifier.preferences, github: Github::Preferences.props)
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
