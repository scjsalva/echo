class Api::TestNotificationsController < ApplicationController
  def create
    Notifier.test(sound: params[:sound])
    head :no_content
  end
end
