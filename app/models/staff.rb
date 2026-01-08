class Staff < ApplicationRecord
  validates :name, presence: true
  default_scope { order(:position) }
  has_secure_password
  enum role: { general: 0, admin: 1 }

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :password, presence: true, length: { minimum: 6 }, allow_nil: true
end
