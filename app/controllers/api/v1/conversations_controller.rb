# app/controllers/api/v1/conversations_controller.rb
module Api
  module V1
    class ConversationsController < ApplicationController
      # Assumes you have an authentication method, e.g., `authenticate_user!`
      # before_action :authenticate_user! 

      def history
        # 1. Get user IDs from params (replace with authenticated user)
        user_id_a = params[:user_id_a].to_i
        user_id_b = params[:user_id_b].to_i 

        # 2. Find the conversation between these two users
        conversation = Conversation
          .where(
            '(sender_id = :a AND receiver_id = :b) OR (sender_id = :b AND receiver_id = :a)',
            a: user_id_a, b: user_id_b
          )
          .first

        if conversation
          # 3. Get processed messages from the conversation
          messages = conversation.get_messages
          render json: messages, status: :ok
        else
          # 4. No conversation found, return empty array
          render json: [], status: :ok
        end
      end

      def user_conversations
        user_id = params[:user_id]
        
        # Get all conversations where user is either sender or receiver
        conversations = Conversation
          .where('sender_id = ? OR receiver_id = ?', user_id, user_id)
          .order(updated_at: :desc)
          .limit(20)
        
        # Format the response with processed messages
        formatted_conversations = conversations.map do |conversation|
          {
            id: conversation.id,
            sender_id: conversation.sender_id,
            receiver_id: conversation.receiver_id,
            messages: conversation.get_messages,
            latest_message: conversation.latest_message,
            created_at: conversation.created_at,
            updated_at: conversation.updated_at
          }
        end
        
        render json: formatted_conversations
      end

      def create
        # Create or update conversation with new message
        sender_id = params[:sender_id].to_i
        receiver_id = params[:receiver_id].to_i
        message_text = params[:message_text]

        # Find or create conversation
        conversation = Conversation.find_or_create_by(
          sender_id: [sender_id, receiver_id].min,
          receiver_id: [sender_id, receiver_id].max
        )

        # Add message with sender information
        conversation.add_message(message_text, sender_id)

        # Return the conversation with latest message
        render json: {
          conversation: conversation,
          latest_message: conversation.latest_message
        }, status: :created
      end
    end
  end
end