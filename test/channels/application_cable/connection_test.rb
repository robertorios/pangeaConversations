# frozen_string_literal: true

require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  tests ApplicationCable::Connection

  test "rejects unauthenticated connection" do
    assert_reject_connection { connect }
  end

  test "rejects connection with blank token" do
    assert_reject_connection { connect params: { token: "" } }
  end

  test "rejects connection with invalid token" do
    assert_reject_connection { connect params: { token: "not.a.jwt" } }
  end

  test "rejects connection with expired token" do
    token = JWT.encode(
      { user_id: 10, typ: "access", exp: 1.hour.ago.to_i },
      ENV.fetch("JWT_SECRET_KEY"),
      "HS256"
    )
    assert_reject_connection { connect params: { token: token } }
  end

  test "rejects non-access token typ" do
    token = JWT.encode(
      { user_id: 10, typ: "refresh", exp: 1.hour.from_now.to_i },
      ENV.fetch("JWT_SECRET_KEY"),
      "HS256"
    )
    assert_reject_connection { connect params: { token: token } }
  end

  test "rejects token missing typ" do
    token = JWT.encode(
      { user_id: 10, exp: 1.hour.from_now.to_i },
      ENV.fetch("JWT_SECRET_KEY"),
      "HS256"
    )
    assert_reject_connection { connect params: { token: token } }
  end

  test "accepts valid access JWT and sets current_user_id" do
    connect params: { token: access_token_for(10) }
    assert_equal 10, connection.current_user_id
  end

  private

  def access_token_for(user_id)
    JWT.encode(
      { user_id: user_id, typ: "access", exp: 1.hour.from_now.to_i },
      ENV.fetch("JWT_SECRET_KEY"),
      "HS256"
    )
  end
end
