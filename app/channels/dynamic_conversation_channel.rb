module DynamicConversationChannel
  # This module dynamically creates channel classes for each conversation
  # Usage: DynamicConversationChannel.create_channel_class("39-40")
  
  def self.create_channel_class(conversation_key)
    # Convert hyphens to underscores for valid Ruby class names
    safe_conversation_key = conversation_key.gsub('-', '_')
    channel_name = "Conversation#{safe_conversation_key}"
    
    # Check if channel class already exists
    return channel_name.constantize if Object.const_defined?(channel_name)
    
    # Create the dynamic channel class
    channel_class = Class.new(ApplicationCable::Channel) do
      def subscribed
        # Extract original conversation key from class name
        safe_conversation_key = self.class.name.gsub('Conversation', '')
        conversation_key = safe_conversation_key.gsub('_', '-')
        user_id = params[:user_id]
        
        # Stream from the conversation-specific channel
        stream_from "conversation_#{conversation_key}"
        
        logger.info "🔌 DYNAMIC CHANNEL CREATED: User #{user_id} subscribed to Conversation#{conversation_key}"
        Rails.logger.info "🔌 DYNAMIC CHANNEL CREATED: User #{user_id} subscribed to Conversation#{conversation_key}"
      end
      
      def unsubscribed
        # Extract original conversation key from class name
        safe_conversation_key = self.class.name.gsub('Conversation', '')
        conversation_key = safe_conversation_key.gsub('_', '-')
        user_id = params[:user_id]
        
        logger.info "🔌 DYNAMIC CHANNEL DISCONNECTED: User #{user_id} unsubscribed from Conversation#{conversation_key}"
        Rails.logger.info "🔌 DYNAMIC CHANNEL DISCONNECTED: User #{user_id} unsubscribed from Conversation#{conversation_key}"
      end
      
      def receive(data)
        # Extract original conversation key from class name
        safe_conversation_key = self.class.name.gsub('Conversation', '')
        conversation_key = safe_conversation_key.gsub('_', '-')
        sender_id = data['sender_id'].to_i
        receiver_id = data['receiver_id'].to_i
        message_text = data['message_text']
        
        logger.info "📨 MESSAGE RECEIVED: #{message_text} from user #{sender_id} to user #{receiver_id}"
        
        # Find or create conversation
        conversation = Conversation.find_or_create_by(
          sender_id: [sender_id, receiver_id].min,
          receiver_id: [sender_id, receiver_id].max
        )
        
        if conversation.persisted?
          # Add message to conversation
          conversation.add_message(message_text, sender_id)
          
          logger.info "✅ MESSAGE SAVED: Message added to conversation #{conversation.id}"
          
          # Broadcast to the conversation-specific channel
          ActionCable.server.broadcast(
            "conversation_#{conversation_key}",
            {
              conversation: conversation.as_json(only: [:id, :sender_id, :receiver_id, :message_text, :created_at, :updated_at]),
              latest_message: conversation.latest_message,
              sender_id: sender_id,
              receiver_id: receiver_id
            }
          )
          
          logger.info "📡 BROADCASTED: Message sent to conversation_#{conversation_key}"
        else
          logger.error "❌ ERROR: Failed to save conversation: #{conversation.errors.full_messages.to_sentence}"
        end
      rescue => e
        logger.error "❌ ERROR in receive method: #{e.message}"
      end
    end
    
    # Define the class in the global namespace
    Object.const_set(channel_name, channel_class)
    
    Rails.logger.info "🏗️ CREATED DYNAMIC CHANNEL CLASS: #{channel_name} (for conversation #{conversation_key})"
    
    channel_class
  end
  
  def self.channel_exists?(conversation_key)
    safe_conversation_key = conversation_key.gsub('-', '_')
    channel_name = "Conversation#{safe_conversation_key}"
    Object.const_defined?(channel_name)
  end
end
