class AddDetailsToLlmApiKey < ActiveRecord::Migration[8.0]
  def change
    add_column :llm_api_keys, :full_name, :string
    add_column :llm_api_keys, :description, :text
    add_column :llm_api_keys, :aliases, :text
  end
end
