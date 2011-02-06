Class.new Sequel::Migration do
  def up
    execute <<-SQL
      CREATE OR REPLACE FUNCTION log_state_change() RETURNS TRIGGER AS $state_change$
      BEGIN
        --
        -- Create a row in state_log to reflect the state change of agents,
        -- make use of the special variable TG_OP to work out the operation.
        --
        IF (TG_OP = 'UPDATE') THEN
            IF OLD.state <> NEW.state THEN
              INSERT INTO state_log SELECT nextval('state_log_id_seq'), OLD.name, OLD.state, NEW.state, now();
              RETURN NEW;
            END IF;
        ELSIF (TG_OP = 'INSERT') THEN
            INSERT INTO state_log SELECT nextval('state_log_id_seq'), OLD.name, 'initial', NEW.state, now();
            RETURN NEW;
        END IF;
        RETURN NULL; -- result is ignored since this is an AFTER trigger
      END;
      $state_change$ LANGUAGE plpgsql;
      CREATE TRIGGER state_log_trigger
      AFTER INSERT OR UPDATE ON agents
        FOR EACH ROW EXECUTE PROCEDURE log_state_change();
    SQL
  end

  def down
    execute <<-SQL
      DROP TRIGGER state_log_trigger on agents;
      DROP FUNCTION log_state_change;
    SQL
  end
end
