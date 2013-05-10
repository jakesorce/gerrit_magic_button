class CreateMagicData < ActiveRecord::Migration
  def up
    create_table :magic_data do |t|
      t.string :patchset
      t.string :project
      t.string :instance_id
      t.string :user
      t.string :state
      t.integer :duration
      t.datetime :time_started
      t.datetime :time_up
    end
  end

  def down
    drop_table :magic_data
  end
end
