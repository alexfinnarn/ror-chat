class AddSummaryAndSuggestedTitleToDocuments < ActiveRecord::Migration[8.0]
  def change
    add_column :documents, :summary, :text
    add_column :documents, :suggested_title, :string
  end
end
