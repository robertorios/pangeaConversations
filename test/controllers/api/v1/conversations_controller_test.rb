# frozen_string_literal: true

require "test_helper"

class ConversationsControllerTest < ActionDispatch::IntegrationTest
  # Fixture user ids (see test/fixtures/conversations.yml)
  USER_A = 10
  USER_B = 20
  USER_C = 30
  SUPERVISOR_1 = 40
  SUPERVISOR_2 = 50

  setup do
    SupervisorDirectory.clear_cache!
  end

  # --- 1. Unauthenticated users cannot access conversation endpoints ---

  test "unauthenticated history request fails" do
    get "/api/v1/conversations/history", params: { user_id_a: USER_A, user_id_b: USER_B }
    assert_response :unauthorized
  end

  test "unauthenticated user_conversations request fails" do
    get "/api/v1/conversations/user/#{USER_A}"
    assert_response :unauthorized
  end

  test "unauthenticated create request fails" do
    post "/api/v1/conversations", params: {
      sender_id: USER_A,
      receiver_id: USER_B,
      message_text: "spoofed"
    }
    assert_response :unauthorized
  end

  # --- 2. User A cannot read User B conversations ---

  test "user A cannot list user B conversations" do
    get "/api/v1/conversations/user/#{USER_B}", headers: auth_headers(USER_A)
    assert_response :forbidden
  end

  test "user A cannot read history for a conversation they are not in" do
    get "/api/v1/conversations/history",
        params: { user_id_a: USER_B, user_id_b: USER_C },
        headers: auth_headers(USER_A)
    assert_response :forbidden
  end

  # --- 3. User A cannot send messages as User B ---

  test "user A cannot send messages as user B" do
    assert_difference -> {
      Conversation.where(
        sender_id: [USER_A, USER_C].min,
        receiver_id: [USER_A, USER_C].max
      ).count
    }, 1 do
      post "/api/v1/conversations",
           params: {
             sender_id: USER_B, # spoofed — must be ignored
             receiver_id: USER_C,
             message_text: "I am pretending to be B"
           },
           headers: auth_headers(USER_A)
    end

    assert_response :created
    body = JSON.parse(response.body)
    latest = body["latest_message"]
    assert_equal USER_A, latest["sender_id"]
    assert_not_equal USER_B, latest["sender_id"]
    assert body["monitored"]
    assert_includes [SUPERVISOR_1, SUPERVISOR_2], body["observer_id"]
  end

  # --- 4. Valid conversation participants can access conversations ---

  test "participant can read their conversation history" do
    get "/api/v1/conversations/history",
        params: { user_id_a: USER_A, user_id_b: USER_B },
        headers: auth_headers(USER_A)
    assert_response :ok

    body = JSON.parse(response.body)
    messages = body["messages"]
    assert_equal 1, messages.length
    assert_equal "hello from A", messages.first["text"]
    assert_equal USER_A, messages.first["sender_id"]
    assert_includes body.keys, "monitored"
  end

  test "participant can list their own conversations" do
    get "/api/v1/conversations/user/#{USER_A}", headers: auth_headers(USER_A)
    assert_response :ok

    conversations = JSON.parse(response.body)
    assert_equal 1, conversations.length
    assert_equal conversations(:between_a_and_b).id, conversations.first["id"]
  end

  test "participant can send a message as themselves" do
    post "/api/v1/conversations",
         params: {
           receiver_id: USER_B,
           message_text: "follow up from A"
         },
         headers: auth_headers(USER_A)

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal USER_A, body["latest_message"]["sender_id"]
    assert_equal "follow up from A", body["latest_message"]["text"]
  end

  # --- 5. Supervisor observer ---

  test "new conversations get a load-balanced supervisor observer" do
    post "/api/v1/conversations",
         params: { receiver_id: USER_C, message_text: "hi C" },
         headers: auth_headers(USER_A)
    assert_response :created
    first = JSON.parse(response.body)
    assert first["monitored"]
    first_observer = first["observer_id"]
    assert_includes [SUPERVISOR_1, SUPERVISOR_2], first_observer

    post "/api/v1/conversations",
         params: { receiver_id: USER_B, message_text: "hi B new thread wait" },
         headers: auth_headers(USER_C)
    # C-B may already exist as fixture between_b_and_c — that gets observer on first message via ensure
    assert_response :created
    second = JSON.parse(response.body)
    assert second["monitored"]
  end

  test "observer can read history but stranger cannot" do
    conv = conversations(:between_a_and_b)
    conv.update!(observer_id: SUPERVISOR_1)

    get "/api/v1/conversations/history",
        params: { user_id_a: USER_A, user_id_b: USER_B },
        headers: auth_headers(SUPERVISOR_1)
    assert_response :ok
    body = JSON.parse(response.body)
    assert body["monitored"]
    assert_equal SUPERVISOR_1, body["observer_id"]

    get "/api/v1/conversations/history",
        params: { user_id_a: USER_A, user_id_b: USER_B },
        headers: auth_headers(SUPERVISOR_2)
    assert_response :forbidden
  end

  test "observer can list observed conversations" do
    conversations(:between_a_and_b).update!(observer_id: SUPERVISOR_1)

    get "/api/v1/conversations/observed", headers: auth_headers(SUPERVISOR_1)
    assert_response :ok
    list = JSON.parse(response.body)
    assert_equal 1, list.length
    assert_equal conversations(:between_a_and_b).id, list.first["id"]

    get "/api/v1/conversations/observed", headers: auth_headers(SUPERVISOR_2)
    assert_response :ok
    assert_equal 0, JSON.parse(response.body).length
  end

  test "load balances observers across supervisors" do
    # Force empty slate conversations for A with fresh partners
    Conversation.where(observer_id: [SUPERVISOR_1, SUPERVISOR_2]).delete_all

    post "/api/v1/conversations",
         params: { receiver_id: 101, message_text: "one" },
         headers: auth_headers(USER_A)
    o1 = JSON.parse(response.body)["observer_id"]

    post "/api/v1/conversations",
         params: { receiver_id: 102, message_text: "two" },
         headers: auth_headers(USER_A)
    o2 = JSON.parse(response.body)["observer_id"]

    assert_includes [SUPERVISOR_1, SUPERVISOR_2], o1
    assert_includes [SUPERVISOR_1, SUPERVISOR_2], o2
    assert_not_equal o1, o2
  end
end
