class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.decimal :amount
      t.references :payer, null: false, foreign_key: { to_table: :users }
      t.references :receiver, null: false, foreign_key: { to_table: :users }
      t.references :group, null: false, foreign_key: true
      t.date :payment_date
      t.string :currency

      t.timestamps
    end
  end
end
