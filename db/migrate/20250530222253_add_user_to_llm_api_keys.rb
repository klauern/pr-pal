class AddUserToLlmApiKeys < ActiveRecord::Migration[8.0]
  def change
    add_reference :llm_api_keys, :user, null: false, foreign_key: true
  end
end
