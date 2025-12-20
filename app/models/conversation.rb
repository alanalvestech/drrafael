class Conversation < ApplicationRecord
  has_many :messages, dependent: :destroy
  
  def self.find_or_create_by_phone(phone)
    find_or_create_by(phone: phone)
  end
  
  def recent_messages(limit: 20)
    messages.order(created_at: :desc).limit(limit).reverse
  end
end

