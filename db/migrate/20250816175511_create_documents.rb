class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :documents do |t|
      t.text :content
      t.string :title
      t.string :file_path
      t.string :content_type
      t.vector :embedding, limit: 1536

      t.timestamps
    end

    add_index :documents, :embedding, using: :hnsw, opclass: :vector_l2_ops
  end
end
