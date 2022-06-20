# frozen_string_literal: true

class UnauthenticatedController < ActionController::API
  def index
    render json: []
  end
end
