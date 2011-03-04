Class.new Sequel::Migration do
  def up
    execute <<-SQL
      CREATE OR REPLACE FUNCTION log_abandons() RETURNS TRIGGER AS $abandoned$
        --
        -- Create a row in abandon_log for each abandoned call
        --
      BEGIN
        INSERT INTO abandon_log (
          queue,
          system,
          uuid,
          caller_number,
          caller_name,
          system_epoch,
          joined_epoch,
          rejoined_epoch,
          bridge_epoch,
          abandoned_epoch,
          base_score,
          skill_score,
          serving_agent,
          serving_system,
          state
          )
        VALUES(
          NEW.queue,
          NEW.system,
          NEW.uuid,
          NEW.caller_number,
          NEW.caller_name,
          NEW.system_epoch,
          NEW.joined_epoch,
          NEW.rejoined_epoch,
          NEW.bridge_epoch,
          NEW.abandoned_epoch,
          NEW.base_score,
          NEW.skill_score,
          NEW.serving_agent,
          NEW.serving_system,
          NEW.state
        );
        RETURN NULL; -- result is ignored since this is an AFTER trigger
      EXCEPTION WHEN unique_violation THEN
        RETURN NULL; -- we don't care about unique_violation errors
      END;
      $abandoned$ LANGUAGE plpgsql;
      CREATE TRIGGER abandon_log_trigger
      AFTER UPDATE OF abandoned_epoch ON members
        FOR EACH ROW
        WHEN (NEW.abandoned_epoch != 0)
          EXECUTE PROCEDURE log_abandons();
    SQL
  end

  def down
    raise "Cannot Go Down from here"
  end
end
