# app/channels/conversation_channel.rb
#
# Frontend Usage:
# 
# ✅ CORRECT: Subscribe to ConversationChannel with parameters
#    const conversationKey = "39-40"; // e.g., for conversation between users 39 and 40
#    const subscription = consumer.subscriptions.create(
#      {
#        channel: 'ConversationChannel',        // ← Always use 'ConversationChannel'
#        conversation_key: conversationKey,      // ← Pass conversation key as parameter
#        user_id: currentUserId
#      },
#      {
#        connected: () => console.log('Connected to Conversation39-40'),
#        received: (data) => console.log('Message received:', data),
#        disconnected: () => console.log('Disconnected from Conversation39-40')
#      }
#    );
#
# ❌ WRONG: Don't try to subscribe to channel names directly
#    consumer.subscriptions.create('Conversation39-40'); // ← This will cause "Subscription class not found" error
#
# 2. Send message:
#    subscription.perform('receive', {
#      sender_id: 39,
#      receiver_id: 40,
#      message_text: "Hello!"
#    });
#
# 3. Channel naming convention:
#    - Conversation key: "39-40" (always sorted, smaller ID first)
#    - Stream name: "Conversation39-40" (internal, managed by Action Cable)
#    - Both users subscribe to the same ConversationChannel with same conversation_key
#
class ConversationChannel < ApplicationCable::Channel
  # This runs when a client attempts to subscribe
  def subscribed
    # 1. Ensure the user is authenticated (you'll need to implement this check)
    #    For simplicity, we'll assume the current_user is available through your authentication logic.
    
    # 2. Identify the conversation key (e.g., "39-40" for conversation between users 39 and 40)
    conversation_key = params[:conversation_key]
    user_id = params[:user_id]
    
    if conversation_key.present?
      # 3a. Stream from conversation-specific channel (e.g., "Conversation39-40")
      channel_name = "Conversation#{conversation_key}"
      stream_from channel_name
      
      # Enhanced logging for conversation-specific channel creation
      logger.info "🔌 CONVERSATION CHANNEL CREATED: User #{user_id} subscribed to #{channel_name}"
      logger.info "📡 STREAMING: ConversationChannel is streaming from #{channel_name}"
      logger.info "✅ SUBSCRIPTION: ConversationChannel is transmitting the subscription confirmation"
      
      # Also log to Rails logger for better visibility
      Rails.logger.info "🔌 CONVERSATION CHANNEL CREATED: User #{user_id} subscribed to #{channel_name}"
    else
      # 3b. Fallback to user-specific channel (backward compatibility)
      channel_name = "conversation_#{user_id}"
      stream_from channel_name
      
      # Enhanced logging for user-specific channel creation
      logger.info "🔌 USER CHANNEL CREATED: User #{user_id} subscribed to #{channel_name}"
      logger.info "📡 STREAMING: ConversationChannel is streaming from #{channel_name}"
      logger.info "✅ SUBSCRIPTION: ConversationChannel is transmitting the subscription confirmation"
      
      # Also log to Rails logger for better visibility
      Rails.logger.info "🔌 USER CHANNEL CREATED: User #{user_id} subscribed to #{channel_name}"
    end
  end

  # When the client disconnects
  def unsubscribed
    conversation_key = params[:conversation_key]
    user_id = params[:user_id]
    
    if conversation_key.present?
      channel_name = "Conversation#{conversation_key}"
      logger.info "🔌 CONVERSATION CHANNEL DISCONNECTED: User #{user_id} unsubscribed from #{channel_name}"
      Rails.logger.info "🔌 CONVERSATION CHANNEL DISCONNECTED: User #{user_id} unsubscribed from #{channel_name}"
    else
      channel_name = "conversation_#{user_id}"
      logger.info "🔌 USER CHANNEL DISCONNECTED: User #{user_id} unsubscribed from #{channel_name}"
      Rails.logger.info "🔌 USER CHANNEL DISCONNECTED: User #{user_id} unsubscribed from #{channel_name}"
    end
  end

  # This runs when a client sends a message to the server (via `chatChannel.perform('receive', data)`)
  def receive(data)
    logger.info "Received message from user #{params[:user_id]}: #{data}"
    
    # Check if we have active streams (simpler approach)
    unless @_streams.present?
      logger.warn "No active streams found for user #{params[:user_id]}. Message will be ignored."
      return
    end
    
    # 1. Basic validation and data extraction
    sender_id = data['sender_id'].to_i  # Use sender_id from client data
    receiver_id = data['receiver_id'].to_i
    message_text = data['message_text']

    # IMPORTANT: Never trust the sender_id directly from the client.
    # We'll use a placeholder `current_user_id` here. You must implement
    # a proper authentication check (e.g., based on a session token or JWT).
    
    # Simple check to prevent self-messaging or missing data
    unless sender_id.present? && receiver_id.present? && message_text.present? && sender_id != receiver_id
      logger.warn "Invalid message data: sender_id=#{sender_id}, receiver_id=#{receiver_id}, message_text=#{message_text}"
      return
    end

    # 2. Find or create conversation thread (ensure consistent ordering)
    # Always use the smaller user_id as sender_id for consistency
    if sender_id < receiver_id
      conversation = Conversation.find_or_create_by(
        sender_id: sender_id,
        receiver_id: receiver_id
      )
    else
      # Swap the order to maintain consistency
      conversation = Conversation.find_or_create_by(
        sender_id: receiver_id,
        receiver_id: sender_id
      )
    end
    
    # Add the new message to the conversation thread with sender information
    conversation.add_message(message_text, sender_id)

    if conversation.persisted?
      logger.info "Message added to conversation: #{conversation.id}"
      
      # Determine the actual sender and receiver for broadcasting
      actual_sender_id = sender_id
      actual_receiver_id = receiver_id
      
      # Create conversation-specific channel name (consistent ordering)
      conversation_key = [sender_id, receiver_id].sort.join('-')
      conversation_channel = "Conversation#{conversation_key}"
      
      # Broadcast to conversation-specific channel
      ActionCable.server.broadcast(
        conversation_channel,
        { 
          conversation: conversation.as_json(only: [:id, :sender_id, :receiver_id, :message_text, :created_at, :updated_at]),
          latest_message: conversation.latest_message,
          actual_sender_id: actual_sender_id,
          actual_receiver_id: actual_receiver_id
        }
      )
      
      logger.info "📡 BROADCASTED: Message sent to #{conversation_channel}"
      
      # NOTE: The `after_create_commit` in the model handles the broadcast to the receiver.
    else
      # Handle creation failure (e.g., logging or broadcasting an error back)
      logger.error "Error saving conversation: #{conversation.errors.full_messages.to_sentence}"
    end
  rescue => e
    logger.error "Error in receive method: #{e.message}"
    logger.error e.backtrace.join("\n")
    
    # If it's a subscription error, try to handle it gracefully
    if e.message.include?("Unable to find subscription")
      logger.warn "Subscription lost for user #{params[:user_id]}. Message may not be delivered."
      # Don't re-raise the error to prevent further issues
    else
      # Re-raise other errors
      raise e
    end
  end
  
  # Placeholder for authentication
  private 
  
  def current_user_id
    # Replace this with your actual authentication logic. 
    # For a microservice, this might involve decoding a JWT from the connection
    # request or looking up a session ID.
    # For now, we assume the user is authenticated and their ID is the one 
    # used in the subscription params (which we should eventually move).
    user_id = params[:user_id].to_i
    if user_id == 0
      logger.error "Invalid user_id in params: #{params[:user_id]}"
      return nil
    end
    user_id
  end
end