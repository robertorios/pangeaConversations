# frozen_string_literal: true

require "jwt"

# Verifies access JWTs minted by pangeaUsers (typ must be "access").
module JwtAccess
  ACCESS_TYP = "access"
  DECODE_OPTIONS = {
    algorithm: "HS256",
    verify_expiration: true
  }.freeze

  module_function

  # Returns the payload Hash, or nil if invalid / wrong type / expired.
  def decode(token, secret)
    return nil if token.blank?

    payload = JWT.decode(token, secret, true, DECODE_OPTIONS)[0]
    return nil unless payload.is_a?(Hash)
    return nil unless payload["typ"] == ACCESS_TYP
    return nil if payload["user_id"].blank?

    payload
  rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::ImmatureSignature
    nil
  end
end
