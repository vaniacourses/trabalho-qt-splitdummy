class ExpenseParticipant < ApplicationRecord
  belongs_to :expense
  belongs_to :user

  validates :amount_owed, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :expense_id, uniqueness: { scope: :user_id, message: "já é um participante desta despesa" }
end
