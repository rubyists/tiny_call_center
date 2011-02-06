Class.new Sequel::Migration do
  def up
    create_table(:state_log) do
      primary_key :id
      String :agent, :null => false
      String :last_state, :null => false
      String :new_state, :null => false
      DateTime :created_at
    end unless DB.tables.include? :state_log
  end

  def down
    remove_table(:state_log) if DB.tables.include? :state_log
  end
end
