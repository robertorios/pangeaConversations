# POST /channels/register — creates a dynamic Conversation{a_b} class for the
# legacy string-subscribe path. Requires JWT auth; only pair participants
# (or the sticky observer) may register a key.
class ChannelsController < ApplicationController
  before_action :authenticate_user!

  def register
    conversation_key = params[:conversation_key].to_s
    ids = conversation_key.split("-").map(&:to_i)

    unless ids.length == 2 && ids.all?(&:positive?) && ids.uniq.length == 2
      render json: {
        success: false,
        error: "Invalid conversation_key"
      }, status: :unprocessable_entity
      return
    end

    uid = current_user_id.to_i
    conversation = Conversation.find_by(sender_id: ids.min, receiver_id: ids.max)
    allowed = ids.include?(uid) || conversation&.observer?(uid)

    unless allowed
      render json: { success: false, error: "Forbidden" }, status: :forbidden
      return
    end

    channel_created = false
    unless DynamicConversationChannel.channel_exists?(conversation_key)
      DynamicConversationChannel.create_channel_class(conversation_key)
      channel_created = true
    end

    channel_name = "Conversation#{conversation_key.gsub('-', '_')}"
    channel_exists = Object.const_defined?(channel_name)

    render json: {
      success: true,
      channel_name: channel_name,
      conversation_key: conversation_key,
      user_id: uid,
      channel_created: channel_created,
      channel_exists: channel_exists,
      ready: channel_exists
    }
  end
end
