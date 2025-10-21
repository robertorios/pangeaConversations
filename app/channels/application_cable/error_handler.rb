module ApplicationCable
  class ErrorHandler
    def self.handle_error(exception, connection)
      Rails.logger.error "ActionCable Error: #{exception.message}"
      Rails.logger.error exception.backtrace.join("\n")
      
      # Handle subscription errors gracefully
      if exception.message.include?("Unable to find subscription")
        Rails.logger.warn "Subscription error handled gracefully - connection maintained"
        # Don't disconnect the connection for subscription errors
        return false
      end
      
      # For other errors, allow normal error handling
      return true
    end
  end
end


