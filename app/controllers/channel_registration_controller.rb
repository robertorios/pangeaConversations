class ChannelRegistrationController < ApplicationController
  # POST /channels/register
  # Registers a new conversation channel dynamically
  def register
    conversation_key = params[:conversation_key]
    user_id = params[:user_id]
    
    if conversation_key.blank? || user_id.blank?
      render json: { error: "conversation_key and user_id are required" }, status: 400
      return
    end
    
    # Create the dynamic channel class if it doesn't exist
    unless DynamicConversationChannel.channel_exists?(conversation_key)
      DynamicConversationChannel.create_channel_class(conversation_key)
      
      # Wait a moment to ensure the class is fully created
      sleep(0.1)
    end
    
    # Verify the channel was created successfully
    channel_name = "Conversation#{conversation_key.gsub('-', '_')}"
    channel_exists = Object.const_defined?(channel_name)
    
    render json: { 
      message: "Channel Conversation#{conversation_key} registered successfully",
      channel_name: "Conversation#{conversation_key}",
      conversation_key: conversation_key,
      user_id: user_id,
      channel_exists: channel_exists,
      ready: channel_exists
    }
  end
  
  # GET /channels/list
  # Lists all registered conversation channels
  def list
    channels = Object.constants
      .select { |c| c.to_s.start_with?('Conversation') }
      .map { |c| c.to_s }
    
    render json: { 
      channels: channels,
      total: channels.count
    }
  end
end
