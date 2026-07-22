require "jwt"

class ApplicationController < ActionController::API
  private

  # Tokens are minted by pangeaUsers. This service has no users table — identity
  # is the integer user_id in the JWT, verified with the shared secret.
  def jwt_secret
    ENV.fetch("JWT_SECRET_KEY")
  end

  # Returns the authenticated user's id (Integer) or nil.
  # Requires typ == "access" and a valid exp claim.
  def current_user_id
    @current_user_id ||= begin
      header = request.headers["Authorization"]
      if header.present?
        token = header.split(" ").last
        payload = JwtAccess.decode(token, jwt_secret)
        payload && Integer(payload["user_id"])
      end
    rescue ArgumentError, TypeError
      nil
    end
  end

  def authenticate_user!
    render json: { error: "Unauthenticated" }, status: :unauthorized unless current_user_id
  end
end
