class RemoveSuggestedTitleFromDocuments < ActiveRecord::Migration[8.0]
  def change
    remove_column :documents, :suggested_title, :string
  end
end
