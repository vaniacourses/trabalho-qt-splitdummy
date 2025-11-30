class GroupMembership < ApplicationRecord
  belongs_to :user
  belongs_to :group

  validates :user_id, uniqueness: { scope: :group_id, message: "já é membro deste grupo" }
  validates :status, presence: true, inclusion: { in: %w[active inactive] }
  validates :joined_at, presence: true
end
