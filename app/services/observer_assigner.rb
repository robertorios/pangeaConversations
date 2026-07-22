# frozen_string_literal: true

# Sticky load-balanced observer: assign the eligible supervisor with the fewest
# observed chats. Eligible = admin ids minus the two chat participants.
class ObserverAssigner
  def self.assign!(conversation)
    eligible = SupervisorDirectory.admin_ids - [conversation.sender_id, conversation.receiver_id]
    return nil if eligible.empty?

    counts = Conversation.where(observer_id: eligible).group(:observer_id).count
    chosen = eligible.min_by { |id| [counts[id] || 0, id] }

    conversation.update!(observer_id: chosen)
    chosen
  end

  # Assign observers to every conversation that is still missing one.
  def self.backfill_missing!
    assigned = 0
    Conversation.where(observer_id: nil).find_each do |conversation|
      conversation.ensure_observer!
      assigned += 1 if conversation.observer_id.present?
    end
    assigned
  end
end
