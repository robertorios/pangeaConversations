# app/models/conversation.rb
class Conversation < ApplicationRecord
    # After a message is successfully saved, broadcast it immediately
    after_create_commit :broadcast_message
  
    private
  
    def broadcast_message
      # Use the receiver's ID to target their specific channel
      ActionCable.server.broadcast(
        "conversation_#{self.receiver_id}", 
        {
          message: self.as_json(only: [:id, :sender_id, :receiver_id, :message_text, :created_at])
        }
      )
    end
  end