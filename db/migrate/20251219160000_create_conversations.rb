class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.string :phone, null: false, index: { unique: true }
      t.timestamps
    end
  end
end

