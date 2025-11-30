class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
      t.string :password_digest
      t.string :default_currency
      t.string :profile_picture_url

      t.timestamps
    end
    add_index :users, :email
  end
end
