class AgentsController < ApplicationController
  def index
    @props = Dashboard.current.agents_props
  end
end
