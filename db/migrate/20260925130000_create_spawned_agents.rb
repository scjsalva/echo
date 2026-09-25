class CreateSpawnedAgents < ActiveRecord::Migration[8.1]
  def change
    create_table :spawned_agents do |t|
      t.integer :pid, null: false
      t.string :purpose, null: false
      t.string :ref
      t.datetime :ended_at
      t.timestamps
    end
    add_index :spawned_agents, :pid
  end
end
