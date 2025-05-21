class CreateLlmApiKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :llm_api_keys do |t|
      t.string :llm_provider
      t.text :api_key

      t.timestamps
    end
    add_index :llm_api_keys, :llm_provider, unique: true
  end
end
