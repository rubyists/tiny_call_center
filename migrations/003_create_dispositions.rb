Class.new Sequel::Migration do
  def up
    create_table(:dispositions) do
      primary_key :id
      String :code, :null => false
      String :key, :null => false
      String :description, :null => false
    end unless DB.tables.include? :dispositions
    [["900", "F1", "Talked To Right Party"],
     ["901", "F2", "Left Message On Machine"],
     ["902", "F3", "Left Message With 3rd Party"],
     ["903", "F4", "Promise Made"],
     ["904", "F5", "Payment Made"],
     ["905", "F6", "Disconnected Number"],
     ["906", "F7", "No Answer"],
     ["907", "F8", "Disputed Debt"],
     ["908", "F9", "Wrong Number"],
     ["909", "F10", "Busy/Fax"],
     ["910", "F11", "No Calls To POE"],
     ["911", "F12", "Transfer To Spanish Speaker"]].each { |row|
      DB[:dispositions].insert(code: row[0], key: row[1], description: row[2])
     }
  end

  def down
    remove_table(:dispositions) if DB.tables.include? :dispositions
  end
end
