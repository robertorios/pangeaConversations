# frozen_string_literal: true

require "test_helper"

class ChannelsControllerTest < ActionDispatch::IntegrationTest
  USER_A = 10
  USER_B = 20
  USER_C = 30

  test "unauthenticated register is rejected" do
    post "/channels/register", params: {
      conversation_key: "#{USER_A}-#{USER_B}",
      user_id: USER_A
    }
    assert_response :unauthorized
  end

  test "participant can register their conversation channel" do
    post "/channels/register",
         params: { conversation_key: "#{USER_A}-#{USER_B}", user_id: USER_C },
         headers: auth_headers(USER_A)

    assert_response :success
    body = JSON.parse(response.body)
    assert body["success"]
    assert_equal USER_A, body["user_id"] # JWT identity, not spoofed USER_C
    assert_equal "Conversation#{USER_A}_#{USER_B}", body["channel_name"]
  end

  test "stranger cannot register another pair's channel" do
    post "/channels/register",
         params: { conversation_key: "#{USER_A}-#{USER_B}", user_id: USER_A },
         headers: auth_headers(USER_C)

    assert_response :forbidden
  end

  test "unauthenticated channel list is rejected" do
    get "/channels/list"
    assert_response :unauthorized
  end
end
