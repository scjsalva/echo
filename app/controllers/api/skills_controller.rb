# Which skill each of Echo's Claude actions uses, for all repos or one.
class Api::SkillsController < ApplicationController
  def show
    action = params.require(:skill_action)
    return head(:not_found) unless Skills::ACTIONS.key?(action)

    repo = params[:repo].presence if Skills::ACTIONS[action][:per_repo]
    render json: camelize(repo ? Skills.repo_props(action, repo) : Skills.props([]).find { it[:action] == action })
  end

  def update
    Skills.choose(params.require(:skill_action), params[:skill].presence, repo: params[:repo].presence)
    render json: camelize(skills: Skills.props(Github::Preferences.repos))
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
