class JiraController < ApplicationController
  def index
    @props = Dashboard.current.jira_props
  end
end
