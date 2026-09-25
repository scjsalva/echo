class InboxController < ApplicationController
  def index
    @props = Dashboard.current.inbox_props
  end
end
