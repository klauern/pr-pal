class AdjustLlmApiKeyIndex < ActiveRecord::Migration[8.0]
  def change
    # Remove old unique index on llm_provider
    remove_index :llm_api_keys, :llm_provider if index_exists?(:llm_api_keys, :llm_provider)

    # Add new composite unique index on [:user_id, :llm_provider]
    add_index :llm_api_keys, [ :user_id, :llm_provider ], unique: true
  end
end
