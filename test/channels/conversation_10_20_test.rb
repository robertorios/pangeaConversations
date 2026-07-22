# frozen_string_literal: true

require "test_helper"

# Ensure the dynamic class exists before ActionCable maps Conversation10_20Test → Conversation10_20.
DynamicConversationChannel.create_channel_class("10-20")

class Conversation10_20Test < ActionCable::Channel::TestCase
  USER_A = 10
  USER_B = 20
  USER_C = 30

  setup do
    SupervisorDirectory.clear_cache!
  end

  test "dynamic channel rejects subscribe for non-participant" do
    stub_connection current_user_id: USER_C
    subscribe

    assert subscription.rejected?
  end

  test "dynamic channel accepts participant and ignores client sender_id" do
    stub_connection current_user_id: USER_A
    subscribe
    assert subscription.confirmed?

    assert_broadcasts("conversation_#{USER_A}-#{USER_B}", 1) do
      perform :receive,
              sender_id: USER_C,
              receiver_id: USER_B,
              message_text: "via dynamic"
    end

    conversation = Conversation.find_by(sender_id: USER_A, receiver_id: USER_B)
    latest = conversation.latest_message
    assert_equal USER_A, latest[:sender_id] || latest["sender_id"]
  end
end
