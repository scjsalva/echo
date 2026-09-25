class Api::ChangesController < ApplicationController
  def show
    render json: { version: Changes.version }
  end
end
