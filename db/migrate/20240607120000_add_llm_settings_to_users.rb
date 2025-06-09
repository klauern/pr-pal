class AddLlmSettingsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :default_llm_provider, :string
    add_column :users, :default_llm_model, :string
  end
end
