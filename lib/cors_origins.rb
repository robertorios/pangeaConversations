# frozen_string_literal: true

# Explicit SPA origins for Rack::Cors (credentials: true forbids "*").
#
# Development/test: localhost defaults + optional CORS_ALLOWED_ORIGINS (tunnels).
# Production: CORS_ALLOWED_ORIGINS only — no localhost, no hardcoded tunnels.
module CorsOrigins
  LOCAL_DEV = [
    "http://localhost:5173",
    "http://127.0.0.1:5173",
    "http://localhost:3000",
    "http://localhost:3001",
    "http://localhost:3002"
  ].freeze

  module_function

  def allowed(rails_env = Rails.env)
    from_env = parse_env(ENV["CORS_ALLOWED_ORIGINS"])
    reject_wildcards!(from_env)

    if rails_env.production?
      if from_env.empty?
        raise "CORS_ALLOWED_ORIGINS must be set to an explicit comma-separated " \
              "list in production (wildcards are not allowed)."
      end
      from_env
    else
      (LOCAL_DEV + from_env).uniq
    end
  end

  def parse_env(value)
    value.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  def reject_wildcards!(origins)
    bad = origins.select { |o| o == "*" || o.include?("*") }
    return if bad.empty?

    raise "CORS origins must be exact URLs (no wildcards): #{bad.join(', ')}"
  end
end
