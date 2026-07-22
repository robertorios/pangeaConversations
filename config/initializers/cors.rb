# Be sure to restart your server when you modify this file.

# Cross-Origin Resource Sharing for the SPA.
# credentials: true requires an explicit origin allowlist (never "*").
# See CorsOrigins — development keeps localhost; production uses CORS_ALLOWED_ORIGINS only.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*CorsOrigins.allowed)

    resource "/api/*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      max_age: 600

    resource "/channels/*",
      headers: :any,
      methods: [:get, :post, :options, :head],
      credentials: true,
      max_age: 600

    resource "/cable",
      headers: :any,
      methods: [:get, :post, :options, :head],
      credentials: true,
      max_age: 600
  end
end
