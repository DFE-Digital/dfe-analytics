# frozen_string_literal: true

class PublicApiController < ActionController::API
  def index
    render json: []
  end
end
