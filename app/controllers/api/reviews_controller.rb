class Api::ReviewsController < ApplicationController
  def show
    render json: camelize(Review.find(params[:id]).to_props)
  end
end
