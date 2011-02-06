Class.new Sequel::Migration do
  def up
    create_table(:status_log) do
      primary_key :id
      String :agent, :null => false
      String :last_status, :null => false
      String :new_status, :null => false
      DateTime :created_at
    end unless DB.tables.include? :status_log
  end

  def down
    remove_table(:status_log) if DB.tables.include? :status_log
  end
end
