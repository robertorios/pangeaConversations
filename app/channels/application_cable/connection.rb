require "jwt"

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user_id

    def connect
      # Reject any socket that does not present a valid token. current_user_id
      # is the verified integer user id — trusted for the life of the socket.
      self.current_user_id = find_verified_user_id

      logger.info "🔌 WEBSOCKET CONNECTED: ActionCable connection established for user: #{current_user_id}"
      Rails.logger.info "🔌 WEBSOCKET CONNECTED: ActionCable connection established for user: #{current_user_id}"
    end

    def disconnect
      logger.info "🔌 WEBSOCKET DISCONNECTED: ActionCable connection disconnected for user: #{current_user_id}"
      Rails.logger.info "🔌 WEBSOCKET DISCONNECTED: ActionCable connection disconnected for user: #{current_user_id}"
    end

    def handle_exception(exception)
      should_disconnect = ErrorHandler.handle_error(exception, self)

      if should_disconnect
        logger.error "Disconnecting due to error: #{exception.message}"
        close
      else
        logger.info "Error handled gracefully, connection maintained"
      end
    end

    private

    # The browser passes the JWT on the cable URL, e.g.
    #   createConsumer(`${WS_URL}/cable?token=${jwt}`)
    # An Authorization header is also accepted for non-browser clients.
    def find_verified_user_id
      token = request.params[:token].presence ||
              request.headers["Authorization"]&.split(" ")&.last
      reject_unauthorized_connection if token.blank?

      payload = JwtAccess.decode(token, ENV.fetch("JWT_SECRET_KEY"))
      reject_unauthorized_connection if payload.nil?

      user_id = payload["user_id"]
      reject_unauthorized_connection if user_id.blank? || user_id.to_i <= 0

      user_id.to_i
    rescue KeyError
      reject_unauthorized_connection
    end
  end
end
