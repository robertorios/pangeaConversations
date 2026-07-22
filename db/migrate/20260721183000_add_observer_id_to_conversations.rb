class AddObserverIdToConversations < ActiveRecord::Migration[8.0]
  def change
    add_column :conversations, :observer_id, :integer
    add_index :conversations, :observer_id
  end
end
