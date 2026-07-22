# app/channels/conversation_channel.rb
#
# Frontend Usage:
#
# ✅ CORRECT: Subscribe to ConversationChannel with parameters
#    const conversationKey = "39-40";
#    const subscription = consumer.subscriptions.create(
#      {
#        channel: 'ConversationChannel',
#        conversation_key: conversationKey
#      },
#      { ... }
#    );
#
# Identity always comes from the verified JWT on the connection — never from
# client params (user_id / sender_id are ignored).
#
class ConversationChannel < ApplicationCable::Channel
  def subscribed
    user_id = verified_user_id
    conversation_key = params[:conversation_key]

    if conversation_key.present?
      unless conversation_accessible?(conversation_key, user_id)
        logger.warn "🚫 REJECTED: user #{user_id} tried to join #{conversation_key}"
        reject
        return
      end

      channel_name = "Conversation#{conversation_key}"
      stream_from channel_name
      logger.info "🔌 CONVERSATION CHANNEL CREATED: User #{user_id} subscribed to #{channel_name}"
      Rails.logger.info "🔌 CONVERSATION CHANNEL CREATED: User #{user_id} subscribed to #{channel_name}"
    else
      # Fallback: personal stream keyed by verified JWT id only.
      channel_name = "conversation_#{user_id}"
      stream_from channel_name
      logger.info "🔌 USER CHANNEL CREATED: User #{user_id} subscribed to #{channel_name}"
      Rails.logger.info "🔌 USER CHANNEL CREATED: User #{user_id} subscribed to #{channel_name}"
    end
  end

  def unsubscribed
    conversation_key = params[:conversation_key]
    user_id = verified_user_id

    if conversation_key.present?
      channel_name = "Conversation#{conversation_key}"
      logger.info "🔌 CONVERSATION CHANNEL DISCONNECTED: User #{user_id} unsubscribed from #{channel_name}"
    else
      channel_name = "conversation_#{user_id}"
      logger.info "🔌 USER CHANNEL DISCONNECTED: User #{user_id} unsubscribed from #{channel_name}"
    end
  end

  # Client may send message_text (+ optional receiver_id for backwards compat).
  # sender_id / receiver_id from the client are never trusted.
  def receive(data)
    data = data.stringify_keys if data.respond_to?(:stringify_keys)
    conversation_key = params[:conversation_key].to_s
    sender_id = verified_user_id
    message_text = data["message_text"]

    unless conversation_key.present?
      logger.warn "🚫 REJECTED send: conversation_key required"
      return
    end

    unless conversation_sender?(conversation_key, sender_id)
      logger.warn "🚫 REJECTED send: user #{sender_id} is not a sender on #{conversation_key}"
      return
    end

    receiver_id = peer_id_for(conversation_key, sender_id)
    unless receiver_id.present? && message_text.present? && sender_id != receiver_id
      logger.warn "🚫 REJECTED send: invalid message payload"
      return
    end

    # Optional client receiver_id must match the authorized peer (ignore otherwise).
    client_receiver = data["receiver_id"].to_i
    if client_receiver.positive? && client_receiver != receiver_id
      logger.warn "🚫 REJECTED send: client receiver_id #{client_receiver} does not match peer #{receiver_id}"
      return
    end

    ids = parse_conversation_key(conversation_key)
    conversation = Conversation.find_or_create_by(
      sender_id: ids.min,
      receiver_id: ids.max
    )

    unless conversation.participant?(sender_id)
      logger.warn "🚫 REJECTED send: user #{sender_id} is not a participant of conversation #{conversation.id}"
      return
    end

    conversation.ensure_observer!
    conversation.add_message(message_text, sender_id)

    if conversation.persisted?
      conversation_channel = conversation.conversation_channel_name

      ActionCable.server.broadcast(
        conversation_channel,
        {
          conversation: conversation.as_json(
            only: [:id, :sender_id, :receiver_id, :observer_id, :message_text, :created_at, :updated_at]
          ),
          latest_message: conversation.latest_message,
          actual_sender_id: sender_id,
          actual_receiver_id: receiver_id,
          monitored: conversation.monitored?
        }
      )

      logger.info "📡 BROADCASTED: Message sent to #{conversation_channel}"
    else
      logger.error "Error saving conversation: #{conversation.errors.full_messages.to_sentence}"
    end
  rescue StandardError => e
    logger.error "Error in receive method: #{e.message}"
    logger.error e.backtrace.join("\n")
    raise e unless e.message.include?("Unable to find subscription")
  end
end
