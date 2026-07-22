# Dynamically creates Conversation{id_id} channel classes for the legacy
# register + string-subscribe path. Authorization mirrors ConversationChannel:
# JWT identity only; client user_id / sender_id are ignored.
module DynamicConversationChannel
  def self.create_channel_class(conversation_key)
    safe_conversation_key = conversation_key.to_s.gsub("-", "_")
    channel_name = "Conversation#{safe_conversation_key}"

    return channel_name.constantize if Object.const_defined?(channel_name)

    channel_class = Class.new(ApplicationCable::Channel) do
      def subscribed
        conversation_key = class_conversation_key
        user_id = verified_user_id

        unless conversation_accessible?(conversation_key, user_id)
          logger.warn "🚫 DYNAMIC REJECTED: user #{user_id} tried to join #{conversation_key}"
          reject
          return
        end

        stream_from "conversation_#{conversation_key}"
        logger.info "🔌 DYNAMIC CHANNEL CREATED: User #{user_id} subscribed to Conversation#{conversation_key}"
        Rails.logger.info "🔌 DYNAMIC CHANNEL CREATED: User #{user_id} subscribed to Conversation#{conversation_key}"
      end

      def unsubscribed
        conversation_key = class_conversation_key
        user_id = verified_user_id
        logger.info "🔌 DYNAMIC CHANNEL DISCONNECTED: User #{user_id} unsubscribed from Conversation#{conversation_key}"
      end

      def receive(data)
        data = data.stringify_keys if data.respond_to?(:stringify_keys)
        conversation_key = class_conversation_key
        sender_id = verified_user_id
        message_text = data["message_text"]

        unless conversation_sender?(conversation_key, sender_id)
          logger.warn "🚫 DYNAMIC REJECTED send: user #{sender_id} not a sender on #{conversation_key}"
          return
        end

        receiver_id = peer_id_for(conversation_key, sender_id)
        unless receiver_id.present? && message_text.present?
          logger.warn "🚫 DYNAMIC REJECTED send: invalid payload"
          return
        end

        client_receiver = data["receiver_id"].to_i
        if client_receiver.positive? && client_receiver != receiver_id
          logger.warn "🚫 DYNAMIC REJECTED send: spoofed receiver_id #{client_receiver}"
          return
        end

        ids = parse_conversation_key(conversation_key)
        conversation = Conversation.find_or_create_by(
          sender_id: ids.min,
          receiver_id: ids.max
        )

        unless conversation.participant?(sender_id)
          logger.warn "🚫 DYNAMIC REJECTED send: not a participant"
          return
        end

        conversation.ensure_observer!
        conversation.add_message(message_text, sender_id)

        if conversation.persisted?
          ActionCable.server.broadcast(
            "conversation_#{conversation_key}",
            {
              conversation: conversation.as_json(
                only: [:id, :sender_id, :receiver_id, :observer_id, :message_text, :created_at, :updated_at]
              ),
              latest_message: conversation.latest_message,
              sender_id: sender_id,
              receiver_id: receiver_id,
              monitored: conversation.monitored?
            }
          )
          logger.info "📡 BROADCASTED: Message sent to conversation_#{conversation_key}"
        else
          logger.error "❌ ERROR: Failed to save conversation: #{conversation.errors.full_messages.to_sentence}"
        end
      rescue StandardError => e
        logger.error "❌ ERROR in receive method: #{e.message}"
      end

      private

      def class_conversation_key
        self.class.name.gsub("Conversation", "").gsub("_", "-")
      end
    end

    Object.const_set(channel_name, channel_class)
    Rails.logger.info "🏗️ CREATED DYNAMIC CHANNEL CLASS: #{channel_name} (for conversation #{conversation_key})"
    channel_class
  end

  def self.channel_exists?(conversation_key)
    safe_conversation_key = conversation_key.to_s.gsub("-", "_")
    channel_name = "Conversation#{safe_conversation_key}"
    Object.const_defined?(channel_name)
  end
end
