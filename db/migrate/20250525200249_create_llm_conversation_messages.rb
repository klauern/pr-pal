class CreateLlmConversationMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :llm_conversation_messages do |t|
      t.references :pull_request_review, null: false, foreign_key: true
      t.string :sender, null: false
      t.text :content, null: false
      t.string :llm_model_used
      t.integer :token_count
      t.text :metadata
      t.datetime :timestamp, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.integer :order, null: false

      t.timestamps
    end

    add_index :llm_conversation_messages, [ :pull_request_review_id, :order ]
    add_index :llm_conversation_messages, :timestamp
  end
end
