# frozen_string_literal: true

require "test_helper"

class ConversationChannelTest < ActionCable::Channel::TestCase
  USER_A = 10
  USER_B = 20
  USER_C = 30

  setup do
    SupervisorDirectory.clear_cache!
  end

  # --- Subscribe authorization ---

  test "rejects subscribe to another user's conversation" do
    stub_connection current_user_id: USER_A
    subscribe conversation_key: "#{USER_B}-#{USER_C}"

    assert subscription.rejected?
  end

  test "accepts subscribe when user is a pair participant" do
    stub_connection current_user_id: USER_A
    subscribe conversation_key: "#{USER_A}-#{USER_B}"

    assert subscription.confirmed?
    assert_has_stream "Conversation#{USER_A}-#{USER_B}"
  end

  test "ignores client user_id param for identity" do
    stub_connection current_user_id: USER_A
    # Spoofed user_id must not grant access to B-C
    subscribe conversation_key: "#{USER_B}-#{USER_C}", user_id: USER_B

    assert subscription.rejected?
  end

  # --- Send authorization ---

  test "rejects sending to an unauthorized receiver while subscribed to another pair" do
    stub_connection current_user_id: USER_A
    subscribe conversation_key: "#{USER_A}-#{USER_B}"
    assert subscription.confirmed?

    assert_no_difference -> { Conversation.where(sender_id: [USER_A, USER_C].min, receiver_id: [USER_A, USER_C].max).count } do
      perform :receive,
              sender_id: USER_A,
              receiver_id: USER_C,
              message_text: "should not create A-C thread via A-B subscription"
    end
  end

  test "rejects spoofed sender_id — message is attributed to JWT user only" do
    stub_connection current_user_id: USER_A
    subscribe conversation_key: "#{USER_A}-#{USER_B}"
    assert subscription.confirmed?

    assert_broadcasts("Conversation#{USER_A}-#{USER_B}", 1) do
      perform :receive,
              sender_id: USER_B, # spoofed — ignored
              receiver_id: USER_B,
              message_text: "hello from A"
    end

    conversation = Conversation.find_by(sender_id: USER_A, receiver_id: USER_B)
    latest = conversation.latest_message
    assert_equal USER_A, latest[:sender_id] || latest["sender_id"]
    assert_equal "hello from A", latest[:text] || latest["text"]
  end

  test "rejects receive when subscribed user is only an observer" do
    conversations(:between_a_and_b).update!(observer_id: USER_C)

    stub_connection current_user_id: USER_C
    subscribe conversation_key: "#{USER_A}-#{USER_B}"
    assert subscription.confirmed?

    before = conversations(:between_a_and_b).get_messages.length
    perform :receive, receiver_id: USER_B, message_text: "observer cannot send"
    conversations(:between_a_and_b).reload
    assert_equal before, conversations(:between_a_and_b).get_messages.length
  end

  # --- Happy path ---

  test "valid users can communicate successfully" do
    stub_connection current_user_id: USER_A
    subscribe conversation_key: "#{USER_A}-#{USER_B}"
    assert subscription.confirmed?

    assert_broadcasts("Conversation#{USER_A}-#{USER_B}", 1) do
      perform :receive, receiver_id: USER_B, message_text: "secure hello"
    end

    conversation = Conversation.find_by(sender_id: USER_A, receiver_id: USER_B)
    assert_includes conversation.get_messages.map { |m| m[:text] }, "secure hello"
  end
end
