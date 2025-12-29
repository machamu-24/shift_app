class Staff < ApplicationRecord
  validates :name, presence: true
  default_scope { order(:position) }
  has_secure_password
  enum role: { general: 0, admin: 1 }

  validates :email, presence: true, uniqueness: true, if: -> { email.present? }
end
