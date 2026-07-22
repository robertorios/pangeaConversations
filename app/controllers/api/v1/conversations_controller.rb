# app/controllers/api/v1/conversations_controller.rb
module Api
  module V1
    class ConversationsController < ApplicationController
      before_action :authenticate_user!

      # GET /api/v1/conversations/history?user_id_a=&user_id_b=
      # Participant or assigned observer may read.
      def history
        user_id_a = params[:user_id_a].to_i
        user_id_b = params[:user_id_b].to_i

        unless valid_pair?(user_id_a, user_id_b)
          render json: { error: "Invalid conversation participants" }, status: :unprocessable_entity
          return
        end

        conversation = find_pair(user_id_a, user_id_b)

        unless can_access_pair?(user_id_a, user_id_b, conversation)
          render json: { error: "Forbidden" }, status: :forbidden
          return
        end

        # Existing threads created before observers existed get assigned lazily.
        if conversation
          conversation.ensure_observer!
          conversation.reload
        end

        render json: {
          messages: conversation ? conversation.get_messages : [],
          monitored: conversation&.monitored? || false,
          observer_id: conversation&.observer_id
        }, status: :ok
      end

      # GET /api/v1/conversations/user/:user_id
      # Always scopes to the JWT identity. A mismatched path user_id is Forbidden.
      def user_conversations
        requested_user_id = params[:user_id].to_i
        if requested_user_id != current_user_id.to_i
          render json: { error: "Forbidden" }, status: :forbidden
          return
        end

        user_id = current_user_id

        conversations = Conversation
          .where("sender_id = ? OR receiver_id = ?", user_id, user_id)
          .order(updated_at: :desc)
          .limit(20)

        conversations.each(&:ensure_observer!)

        render json: conversations.map { |c| serialize_conversation(c.reload) }
      end

      # GET /api/v1/conversations/observed
      # Threads where the JWT user is the sticky supervisor observer.
      def observed
        ObserverAssigner.backfill_missing!

        conversations = Conversation
          .where(observer_id: current_user_id)
          .order(updated_at: :desc)
          .limit(50)

        render json: conversations.map { |c| serialize_conversation(c) }
      end

      # POST /api/v1/conversations
      # Sender is always the verified JWT user — params[:sender_id] is ignored.
      # Observers cannot post.
      def create
        sender_id = current_user_id.to_i
        receiver_id = params[:receiver_id].to_i
        message_text = params[:message_text]

        if receiver_id <= 0 || message_text.blank? || sender_id == receiver_id
          render json: { error: "Invalid message" }, status: :unprocessable_entity
          return
        end

        conversation = Conversation.find_or_create_by(
          sender_id: [sender_id, receiver_id].min,
          receiver_id: [sender_id, receiver_id].max
        )

        unless conversation.participant?(sender_id)
          render json: { error: "Forbidden" }, status: :forbidden
          return
        end

        conversation.ensure_observer!
        conversation.add_message(message_text, sender_id)

        render json: {
          conversation: conversation.as_json(
            only: [:id, :sender_id, :receiver_id, :observer_id, :created_at, :updated_at]
          ),
          latest_message: conversation.latest_message,
          monitored: conversation.monitored?,
          observer_id: conversation.observer_id
        }, status: :created
      end

      private

      def valid_pair?(a, b)
        a.positive? && b.positive? && a != b
      end

      def find_pair(a, b)
        Conversation.find_by(
          sender_id: [a, b].min,
          receiver_id: [a, b].max
        )
      end

      def can_access_pair?(a, b, conversation)
        uid = current_user_id.to_i
        return true if uid == a || uid == b
        return true if conversation&.observer?(uid)

        false
      end

      def serialize_conversation(conversation)
        {
          id: conversation.id,
          sender_id: conversation.sender_id,
          receiver_id: conversation.receiver_id,
          observer_id: conversation.observer_id,
          monitored: conversation.monitored?,
          messages: conversation.get_messages,
          latest_message: conversation.latest_message,
          created_at: conversation.created_at,
          updated_at: conversation.updated_at
        }
      end
    end
  end
end
