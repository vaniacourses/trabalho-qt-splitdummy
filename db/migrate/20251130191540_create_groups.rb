class CreateGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :groups do |t|
      t.string :name
      t.text :description
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.string :group_type

      t.timestamps
    end
  end
end
