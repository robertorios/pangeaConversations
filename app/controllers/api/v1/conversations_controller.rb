# app/controllers/api/v1/conversations_controller.rb
module Api
    module V1
      class ConversationsController < ApplicationController
        # Assumes you have an authentication method, e.g., `authenticate_user!`
        # before_action :authenticate_user! 
  
        def history
          # 1. Get user IDs from params (replace with authenticated user)
          # Assuming `current_user` method returns the authenticated user object or ID
          user_id_a = params[:user_id_a].to_i
          user_id_b = params[:user_id_b].to_i 
  
          # 2. Fetch messages where sender and receiver match the pair in either direction,
          #    ordered by creation time.
          messages = Conversation
            .where(
              '(sender_id = :a AND receiver_id = :b) OR (sender_id = :b AND receiver_id = :a)',
              a: user_id_a, b: user_id_b
            )
            .order(created_at: :asc)
            .limit(100) # Limit history size
  
          render json: messages, status: :ok
        end

        def user_conversations
            user_id = params[:user_id]
            
            # Get all conversations where user is either sender or receiver
            conversations = Conversation
              .where('sender_id = ? OR receiver_id = ?', user_id, user_id)
              .order(updated_at: :desc)
              .limit(20)
            
            render json: conversations
        end
      end
    end
  end