class ChangeEmbeddingDimensionForNomicModel < ActiveRecord::Migration[8.0]
  def up
    # Remove the existing index first
    remove_index :documents, :embedding

    # Change the embedding column dimension from 1536 to 768 for nomic-embed-text
    change_column :documents, :embedding, :vector, limit: 768

    # Recreate the index
    add_index :documents, :embedding, using: :hnsw, opclass: :vector_l2_ops
  end

  def down
    # Remove the index
    remove_index :documents, :embedding

    # Change back to 1536 dimensions
    change_column :documents, :embedding, :vector, limit: 1536

    # Recreate the index
    add_index :documents, :embedding, using: :hnsw, opclass: :vector_l2_ops
  end
end
