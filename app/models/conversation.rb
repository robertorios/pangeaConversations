# app/models/conversation.rb
class Conversation < ApplicationRecord
  # After a message is successfully saved, broadcast it immediately
  after_create_commit :broadcast_message
  
  # Add methods to handle JSONB message_text with sender and receiver information
  def add_message(text, sender_id, timestamp = nil)
    timestamp ||= Time.current.iso8601
    current_messages = message_text || {}
    
    # Determine receiver_id (the other participant in the conversation)
    receiver_id = (sender_id == self.sender_id) ? self.receiver_id : self.sender_id
    
    # Store message with sender and receiver information
    current_messages[timestamp] = {
      "text" => text,
      "sender_id" => sender_id,
      "receiver_id" => receiver_id
    }
    
    update!(message_text: current_messages)
  end
  
  # Backward compatibility method (for old format)
  def add_message_legacy(text, timestamp = nil)
    timestamp ||= Time.current.iso8601
    current_messages = message_text || {}
    current_messages[timestamp] = text
    update!(message_text: current_messages)
  end
  
  def get_messages
    return [] unless message_text.is_a?(Hash)
    
    message_text.map do |timestamp, message_data|
      if message_data.is_a?(String)
        # Old format: just text
        {
          timestamp: timestamp,
          text: message_data,
          sender_id: nil, # Unknown sender for old format
          receiver_id: nil # Unknown receiver for old format
        }
      else
        # New format: object with text, sender_id, and receiver_id
        {
          timestamp: timestamp,
          text: message_data["text"],
          sender_id: message_data["sender_id"],
          receiver_id: message_data["receiver_id"]
        }
      end
    end.sort_by { |msg| msg[:timestamp] }
  end
  
  def latest_message
    return nil if message_text.blank?
    latest_timestamp = message_text.keys.max
    message_data = message_text[latest_timestamp]
    
    if message_data.is_a?(String)
      # Old format
      {
        timestamp: latest_timestamp,
        text: message_data,
        sender_id: nil,
        receiver_id: nil
      }
    else
      # New format
      {
        timestamp: latest_timestamp,
        text: message_data["text"],
        sender_id: message_data["sender_id"],
        receiver_id: message_data["receiver_id"]
      }
    end
  end

  # Helper method to generate conversation key for channel naming
  def conversation_key
    [sender_id, receiver_id].sort.join('-')
  end
  
  # Helper method to generate conversation channel name
  def conversation_channel_name
    "Conversation#{conversation_key}"
  end

  private

  def broadcast_message
    # Use helper method to create conversation-specific channel name
    conversation_channel = self.conversation_channel_name
    
    # Broadcast to conversation-specific channel
    ActionCable.server.broadcast(
      conversation_channel,
      {
        conversation: self.as_json(only: [:id, :sender_id, :receiver_id, :message_text, :created_at, :updated_at]),
        latest_message: self.latest_message
      }
    )
    
    Rails.logger.info "📡 MODEL BROADCAST: Message sent to #{conversation_channel}"
  end
  
  def send_push_notification
    # Enqueue the background job using the message ID
    # Sidekiq will pick this up and execute the FCM request.
    PushNotificationWorker.perform_async(self.id)
  end
end