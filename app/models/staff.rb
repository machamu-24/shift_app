class Staff < ApplicationRecord
  validates :name, presence: true
  default_scope { order(:position) }
end
