class CreateExpenseParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :expense_participants do |t|
      t.references :expense, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.decimal :amount_owed

      t.timestamps
    end
  end
end
