class CreateConversations < ActiveRecord::Migration[8.0]
  def change
    create_table :conversations do |t|
      t.integer :sender_id
      t.integer :receiver_id
      t.text :message_text
      t.datetime :read_at

      t.timestamps
    end
  end
end
