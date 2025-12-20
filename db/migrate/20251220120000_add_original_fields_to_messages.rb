class AddOriginalFieldsToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :original_type, :string
    add_column :messages, :original_media_url, :string
  end
end

