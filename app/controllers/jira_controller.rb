class JiraController < ApplicationController
  def index
    @props = Dashboard.current.jira_props
  end

  def work
    @props = Dashboard.current.jira_props.merge(work: Jira::FindWork.list)
  end
end
