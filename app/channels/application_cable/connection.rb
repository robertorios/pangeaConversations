module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user_id

    def connect
      # For now, accept all connections
      # In production, you'd validate authentication here
      self.current_user_id = "anonymous_#{SecureRandom.hex(4)}"
      logger.info "ActionCable connection established for user: #{current_user_id}"
    end

    def disconnect
      logger.info "ActionCable connection disconnected for user: #{current_user_id}"
    end
  end
end
