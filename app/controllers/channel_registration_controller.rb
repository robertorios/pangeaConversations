# Legacy registration helpers. List requires authentication.
class ChannelRegistrationController < ApplicationController
  before_action :authenticate_user!

  # GET /channels/list
  def list
    channels = Object.constants
      .select { |c| c.to_s.match?(/\AConversation\d+_\d+\z/) }
      .map(&:to_s)

    render json: {
      channels: channels,
      total: channels.count
    }
  end
end
