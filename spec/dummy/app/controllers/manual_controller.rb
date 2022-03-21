class ManualController < ActionController::Base
  include DfE::Analytics::Requests

  def index
    render plain: 'hello'
  end

  def current_user
    Struct.new(:id).new(123)
  end

  def current_namespace
    'foo'
  end
end
