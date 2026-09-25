class SettingsController < ApplicationController
  def show
    @props = Dashboard.current.settings_props
  end
end
