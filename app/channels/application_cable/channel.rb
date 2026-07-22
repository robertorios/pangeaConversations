module ApplicationCable
  class Channel < ActionCable::Channel::Base
    private

    # Verified JWT identity from the connection — never from client params.
    def verified_user_id
      current_user_id.to_i
    end

    # "39-40" → [39, 40]. Returns nil if malformed.
    def parse_conversation_key(key)
      ids = key.to_s.split("-").map(&:to_i)
      return nil unless ids.length == 2 && ids.all?(&:positive?) && ids[0] != ids[1]

      ids
    end

    # Pair member or sticky supervisor observer may subscribe / listen.
    def conversation_accessible?(conversation_key, user_id = verified_user_id)
      ids = parse_conversation_key(conversation_key)
      return false unless ids

      uid = user_id.to_i
      return true if ids.include?(uid)

      conversation = Conversation.find_by(sender_id: ids.min, receiver_id: ids.max)
      conversation&.observer?(uid) || false
    end

    # Only the two pair participants may send (observers are read-only).
    def conversation_sender?(conversation_key, user_id = verified_user_id)
      ids = parse_conversation_key(conversation_key)
      return false unless ids

      ids.include?(user_id.to_i)
    end

    # Other participant in the key; nil if current user is not in the pair.
    def peer_id_for(conversation_key, user_id = verified_user_id)
      ids = parse_conversation_key(conversation_key)
      return nil unless ids

      uid = user_id.to_i
      return nil unless ids.include?(uid)

      (ids - [uid]).first
    end
  end
end
