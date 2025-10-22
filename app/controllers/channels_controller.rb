class ChannelsController < ApplicationController
  def register
    conversation_key = params[:conversation_key]
    user_id = params[:user_id]
    
    Rails.logger.info "Registering channel for conversation: #{conversation_key}, user: #{user_id}"
    
    # Validate required parameters
    if conversation_key.blank? || user_id.blank?
      render json: { 
        success: false, 
        error: "conversation_key and user_id are required" 
      }, status: 400
      return
    end
    
    # Actually create the dynamic channel class if it doesn't exist
    channel_created = false
    unless DynamicConversationChannel.channel_exists?(conversation_key)
      DynamicConversationChannel.create_channel_class(conversation_key)
      channel_created = true
      
      # Wait a moment to ensure the class is fully created
      sleep(0.1)
    end
    
    # Verify the channel was created successfully
    channel_name = "Conversation#{conversation_key.gsub('-', '_')}"
    channel_exists = Object.const_defined?(channel_name)
    
    Rails.logger.info "Channel registration result: exists=#{channel_exists}, created=#{channel_created}"
    
    render json: { 
      success: true, 
      channel_name: "Conversation#{conversation_key.gsub('-', '_')}",
      conversation_key: conversation_key,
      user_id: user_id,
      channel_created: channel_created,
      channel_exists: channel_exists,
      ready: channel_exists
    }
  end
end
