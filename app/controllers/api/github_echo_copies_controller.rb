# Deletes Echo's own copy of a repo, e.g. once AI reviews read from your clone.
class Api::GithubEchoCopiesController < ApplicationController
  def destroy
    Github::Checkout.remove_echo_copy(params[:repo])
    render json: camelize(github: Github::Preferences.props)
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
