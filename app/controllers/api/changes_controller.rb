class Api::ChangesController < ApplicationController
  def show
    # With shell=1, also the header's counts, for pages that don't load the dashboard.
    body = { version: Changes.version }
    body[:shell] = camelize(Dashboard.current.shell_props) if params[:shell]
    render json: body
  end
end
