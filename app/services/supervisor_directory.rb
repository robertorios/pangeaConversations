# frozen_string_literal: true

# Fetches supervisor (admin) user ids from pangeaUsers for chat observer assignment.
# Prefer INTERNAL_SERVICE_TOKEN + USERS_SERVICE_URL; fall back to SUPERVISOR_USER_IDS.
require "net/http"
require "json"

class SupervisorDirectory
  CACHE_KEY = "supervisor_admin_user_ids"
  CACHE_TTL = 2.minutes

  def self.admin_ids
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { fetch_admin_ids! }
  end

  def self.clear_cache!
    Rails.cache.delete(CACHE_KEY)
  end

  def self.fetch_admin_ids!
    from_env = parse_env_ids
    return from_env unless internal_token_usable?

    from_users = fetch_from_users_service
    return from_users if from_users.any?

    from_env
  rescue StandardError => e
    Rails.logger.error("SupervisorDirectory: #{e.class}: #{e.message}")
    parse_env_ids
  end

  def self.parse_env_ids
    ENV.fetch("SUPERVISOR_USER_IDS", "")
      .split(",")
      .map(&:strip)
      .grep(/\A\d+\z/)
      .map(&:to_i)
      .reject(&:zero?)
      .uniq
  end

  def self.internal_token_usable?
    token = ENV["INTERNAL_SERVICE_TOKEN"].to_s
    token.present? && !token.include?("<") && !token.include?("openssl")
  end

  def self.fetch_from_users_service
    return [] unless internal_token_usable?

    base = ENV.fetch("USERS_SERVICE_URL", "http://127.0.0.1:3000").to_s.chomp("/")
    uri = URI("#{base}/api/internal/admin_user_ids")
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 2
    http.read_timeout = 3
    request = Net::HTTP::Get.new(uri)
    request["X-Internal-Token"] = ENV["INTERNAL_SERVICE_TOKEN"].to_s
    request["Accept"] = "application/json"

    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn("SupervisorDirectory: users service returned #{response.code}")
      return []
    end

    body = JSON.parse(response.body)
    Array(body["admin_user_ids"]).map(&:to_i).reject(&:zero?).uniq
  end

  private_class_method :parse_env_ids, :internal_token_usable?, :fetch_from_users_service, :fetch_admin_ids!
end
