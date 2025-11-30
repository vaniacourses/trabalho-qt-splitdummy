class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.string :description
      t.decimal :total_amount
      t.references :payer, null: false, foreign_key: { to_table: :users }
      t.references :group, null: false, foreign_key: true
      t.date :expense_date
      t.string :currency

      t.timestamps
    end
  end
end
