Class.new Sequel::Migration do
  def up
    create_table(:abandon_log) do
      primary_key :id
      String :queue
      String :system
      String :uuid, :null => false, :unique => true
      String :session_uuid
      String :cid_number
      String :cid_name
      Integer :system_epoch
      Integer :joined_epoch
      Integer :rejoined_epoch
      Integer :bridge_epoch
      Integer :abandoned_epoch
      Integer :base_score
      Integer :skill_score
      String :serving_agent
      String :serving_system
      String :state
    end unless DB.tables.include? :abandon_log
  end

  def down
    drop_table(:abandon_log) if DB.tables.include? :abandon_log
  end
end

=begin Current mod_cc members table
                              Table "public.members"
     Column      |          Type          |               Modifiers
-----------------+------------------------+----------------------------------------
 queue           | character varying(255) |
 system          | character varying(255) |
 uuid            | character varying(255) | not null default ''::character varying
 session_uuid    | character varying(255) | not null default ''::character varying
 cid_number      | character varying(255) |
 cid_name        | character varying(255) |
 system_epoch    | integer                | not null default 0
 joined_epoch    | integer                | not null default 0
 rejoined_epoch  | integer                | not null default 0
 bridge_epoch    | integer                | not null default 0
 abandoned_epoch | integer                | not null default 0
 base_score      | integer                | not null default 0
 skill_score     | integer                | not null default 0
 serving_agent   | character varying(255) |
 serving_system  | character varying(255) |
 state           | character varying(255) |
=end
