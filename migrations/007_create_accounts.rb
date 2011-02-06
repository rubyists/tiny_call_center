Class.new Sequel::Migration do
  def up
    create_table(:accounts) do
      primary_key :id
      String :username, null: false
      String :password, null: false
      String :first_name, null: false
      String :last_name, null: false
      String :extension, null: false
      String :registration_server, null: false
    end unless DB.tables.include? :accounts
  end

  def down
    remove_table(:accounts) if DB.tables.include? :accounts
  end
end
