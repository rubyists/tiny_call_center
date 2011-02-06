Class.new Sequel::Migration do
  def up
    execute <<-SQL
      CREATE OR REPLACE FUNCTION log_status_change() RETURNS TRIGGER AS $status_change$
      BEGIN
        --
        -- Create a row in status_log to reflect the status change of agents,
        -- make use of the special variable TG_OP to work out the operation.
        --
        IF (TG_OP = 'UPDATE') THEN
            IF OLD.status <> NEW.status THEN
              INSERT INTO status_log SELECT nextval('status_log_id_seq'), OLD.name, OLD.status, NEW.status, now();
              RETURN NEW;
            END IF;
        ELSIF (TG_OP = 'INSERT') THEN
            INSERT INTO status_log SELECT nextval('status_log_id_seq'), OLD.name, 'initial', NEW.status, now();
            RETURN NEW;
        END IF;
        RETURN NULL; -- result is ignored since this is an AFTER trigger
      END;
      $status_change$ LANGUAGE plpgsql;
      CREATE TRIGGER status_log_trigger
      AFTER INSERT OR UPDATE ON agents
        FOR EACH ROW EXECUTE PROCEDURE log_status_change();
    SQL
  end

  def down
    execute <<-SQL
      DROP TRIGGER status_log_trigger on agents;
      DROP FUNCTION log_status_change;
    SQL
  end
end
