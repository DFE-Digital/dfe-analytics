# frozen_string_literal: true

class ApplicationController < ActionController::Base
  def index
    render plain: ''
  end

  def current_user
    Struct.new(:id).new(1)
  end

  def current_namespace
    'ddd'
  end
end
