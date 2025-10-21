module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user_id

    def connect
      # For now, accept all connections
      # In production, you'd validate authentication here
      self.current_user_id = "anonymous_#{SecureRandom.hex(4)}"
      
      # Enhanced logging for WebSocket connection establishment
      logger.info "🔌 WEBSOCKET CONNECTED: ActionCable connection established for user: #{current_user_id}"
      Rails.logger.info "🔌 WEBSOCKET CONNECTED: ActionCable connection established for user: #{current_user_id}"
    end

    def disconnect
      # Enhanced logging for WebSocket disconnection
      logger.info "🔌 WEBSOCKET DISCONNECTED: ActionCable connection disconnected for user: #{current_user_id}"
      Rails.logger.info "🔌 WEBSOCKET DISCONNECTED: ActionCable connection disconnected for user: #{current_user_id}"
    end
    
    # Handle connection errors gracefully
    def handle_exception(exception)
      # Use our custom error handler
      should_disconnect = ErrorHandler.handle_error(exception, self)
      
      if should_disconnect
        logger.error "Disconnecting due to error: #{exception.message}"
        close
      else
        logger.info "Error handled gracefully, connection maintained"
      end
    end
  end
end
