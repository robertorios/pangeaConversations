ENV["RAILS_ENV"] ||= "test"
# Shared with pangeaUsers in real envs; tests need a deterministic secret when .env is absent.
ENV["JWT_SECRET_KEY"] ||= "test-jwt-secret-for-conversations"
# Deterministic supervisors for observer assignment in tests (no users HTTP).
ENV["SUPERVISOR_USER_IDS"] ||= "40,50"
ENV.delete("INTERNAL_SERVICE_TOKEN")

require_relative "../config/environment"
require "rails/test_help"
require "jwt"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  # Mint a short-lived access JWT the same way pangeaUsers does.
  def auth_headers(user_id)
    token = JWT.encode(
      { user_id: user_id, typ: "access", exp: 1.hour.from_now.to_i },
      ENV.fetch("JWT_SECRET_KEY"),
      "HS256"
    )
    { "Authorization" => "Bearer #{token}" }
  end
end
