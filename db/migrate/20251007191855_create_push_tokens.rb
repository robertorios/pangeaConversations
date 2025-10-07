class CreatePushTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :push_tokens do |t|
      t.integer :user_id
      t.string :token

      t.timestamps
    end
  end
end
