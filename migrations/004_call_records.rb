Class.new Sequel::Migration do
  def up
    create_table(:call_records) do
      primary_key :id
      String :caller_id_number, :null => false
      String :caller_id_name
      String :destination_number, :null => false
      String :queue_name
      String :uuid, :null => false, :unique => true
      String :channel, :null => false
      DateTime :created_at
      foreign_key :disposition_id, :dispositions
    end unless DB.tables.include? :call_records
  end

  def down
    remove_table(:call_records) if DB.tables.include? :call_records
  end
end
