class Api::AgentsController < ApplicationController
  def index
    render json: camelize(Dashboard.current.agents_props)
  end
end
