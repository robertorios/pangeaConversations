# app/models/conversation.rb
class Conversation < ApplicationRecord
  # After a message is successfully saved, broadcast it immediately
  after_create_commit :broadcast_message

  def participant?(user_id)
    uid = user_id.to_i
    uid == sender_id || uid == receiver_id
  end

  def observer?(user_id)
    observer_id.present? && observer_id.to_i == user_id.to_i
  end

  def accessible_by?(user_id)
    participant?(user_id) || observer?(user_id)
  end

  def monitored?
    observer_id.present?
  end

  # Sticky supervisor observer — assign once, load-balanced across admins.
  def ensure_observer!
    return observer_id if observer_id.present?

    with_lock do
      reload
      return observer_id if observer_id.present?

      ObserverAssigner.assign!(self)
      observer_id
    end
  end

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
        {
          timestamp: timestamp,
          text: message_data,
          sender_id: nil,
          receiver_id: nil
        }
      else
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
      {
        timestamp: latest_timestamp,
        text: message_data,
        sender_id: nil,
        receiver_id: nil
      }
    else
      {
        timestamp: latest_timestamp,
        text: message_data["text"],
        sender_id: message_data["sender_id"],
        receiver_id: message_data["receiver_id"]
      }
    end
  end

  def conversation_key
    [sender_id, receiver_id].sort.join("-")
  end

  def conversation_channel_name
    "Conversation#{conversation_key}"
  end

  private

  def broadcast_message
    conversation_channel = conversation_channel_name

    ActionCable.server.broadcast(
      conversation_channel,
      {
        conversation: as_json(only: [:id, :sender_id, :receiver_id, :observer_id, :message_text, :created_at, :updated_at]),
        latest_message: latest_message,
        monitored: monitored?
      }
    )

    Rails.logger.info "📡 MODEL BROADCAST: Message sent to #{conversation_channel}"
  end

  def send_push_notification
    PushNotificationWorker.perform_async(id)
  end
end
