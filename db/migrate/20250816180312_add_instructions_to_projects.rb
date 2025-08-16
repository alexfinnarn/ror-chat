class AddInstructionsToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :instructions, :text
  end
end
