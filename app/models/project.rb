class Project < ApplicationRecord
  belongs_to :user
  has_many :chats, dependent: :destroy
  has_many :documents, dependent: :destroy

  validates :name, presence: true
end
