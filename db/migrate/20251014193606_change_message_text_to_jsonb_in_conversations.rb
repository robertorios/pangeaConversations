class ChangeMessageTextToJsonbInConversations < ActiveRecord::Migration[8.0]
  def up
    # First, migrate existing data to JSON format for MySQL
    execute <<-SQL
      UPDATE conversations 
      SET message_text = JSON_OBJECT(
        DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%sZ'), 
        message_text
      )
    SQL
    
    # Change column type to JSON (MySQL equivalent of JSONB)
    change_column :conversations, :message_text, :json
    
    # Note: MySQL JSON indexing requires generated columns, skipping for now
  end

  def down
    # Convert back to text (this will lose the JSON structure)
    change_column :conversations, :message_text, :text
    
    # Note: This will convert the JSON back to text, losing the structured format
    execute <<-SQL
      UPDATE conversations 
      SET message_text = CAST(message_text AS CHAR)
    SQL
  end
end
