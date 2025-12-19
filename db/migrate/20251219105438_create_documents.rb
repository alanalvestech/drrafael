class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    enable_extension "vector"

    create_table :documents do |t|
      t.text :content, null: false
      t.string :filename, null: false
      t.vector :embedding, limit: 768, null: false
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :documents, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end

