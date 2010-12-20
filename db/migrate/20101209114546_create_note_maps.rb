class CreateNoteMaps < ActiveRecord::Migration
  def self.up
    create_table :note_maps do |t|
      t.integer :contact_map_id
      t.integer :author_user_map_id
      t.integer :rg_note_id
      t.integer :hr_note_id

      t.timestamps
    end
  end

  def self.down
    drop_table :note_maps
  end
end
