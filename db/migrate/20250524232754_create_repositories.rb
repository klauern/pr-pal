class CreateRepositories < ActiveRecord::Migration[8.0]
  def change
    create_table :repositories do |t|
      t.string :owner
      t.string :name
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
