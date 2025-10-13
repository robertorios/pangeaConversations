# app/channels/conversation_channel.rb
class ConversationChannel < ApplicationCable::Channel
  # This runs when a client attempts to subscribe
  def subscribed
    # 1. Ensure the user is authenticated (you'll need to implement this check)
    #    For simplicity, we'll assume the current_user is available through your authentication logic.
    
    # 2. Identify the unique conversation ID or channel name.
    #    The 'params[:user_id]' will be sent from the React client upon connection.
    user_id = params[:user_id] 
    
    # 3. Stream from a unique channel name based on the user ID.
    #    A user listens to their own channel to receive messages from anyone.
    stream_from "conversation_#{user_id}"
    
    # Log successful subscription
    logger.info "User #{user_id} subscribed to conversation_#{user_id}"
  end

  # When the client disconnects
  def unsubscribed
    # Log disconnection
    logger.info "User #{params[:user_id]} unsubscribed from conversation_#{params[:user_id]}"
  end

  # This runs when a client sends a message to the server (via `chatChannel.perform('receive', data)`)
  def receive(data)
    logger.info "Received message from user #{params[:user_id]}: #{data}"
    
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

    # 2. Create and persist the message
    message = Conversation.create(
      sender_id: sender_id,
      receiver_id: receiver_id,
      message_text: message_text
      # read_at will be null initially
    )

    if message.persisted?
      logger.info "Message saved successfully: #{message.id}"
      # OPTIONAL: Broadcast back to the sender as well, so their client updates
      # instantly with the permanent message ID and timestamp from the DB.
      ActionCable.server.broadcast(
        "conversation_#{sender_id}",
        { message: message.as_json(only: [:id, :sender_id, :receiver_id, :message_text, :created_at]) }
      )
      
      # NOTE: The `after_create_commit` in the model handles the broadcast to the receiver.
    else
      # Handle creation failure (e.g., logging or broadcasting an error back)
      logger.error "Error saving message: #{message.errors.full_messages.to_sentence}"
    end
  rescue => e
    logger.error "Error in receive method: #{e.message}"
    logger.error e.backtrace.join("\n")
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