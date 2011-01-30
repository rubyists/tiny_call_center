Class.new Sequel::Migration do
  def up
    create_table(:managers) do
      primary_key :id
      String :username, :null => false
      String :include, :default => /^9998$/.to_s
      String :exclude, :default => /^((?:2[3456]|34)00|2613|3150)$/.to_s
    end unless DB.tables.include? :managers
  end
  
  def down
    remove_table(:managers) if DB.tables.include? :managers
  end
end
