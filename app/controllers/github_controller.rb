class GithubController < ApplicationController
  def index
    @props = Dashboard.current.github_props
  end
end
