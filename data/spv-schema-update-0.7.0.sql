SET search_path = spv, pg_catalog;

--
-- repeat_on_error feature
--
ALTER TABLE spv.checks ADD COLUMN repeat_on_error integer;
UPDATE spv.checks SET repeat_on_error=repeat;
ALTER TABLE spv.checks ALTER COLUMN repeat_on_error SET NOT NULL;
ALTER TABLE spv.checks
	DROP CONSTRAINT strictly_positive_time,
	ADD CONSTRAINT strictly_positive_time CHECK (repeat > 0 AND repeat_on_error > 0);

--
-- Add triggers for webengine-spv sevices
--

CREATE FUNCTION check_infos_insert_fn() RETURNS "trigger"
    AS $$BEGIN
    if (SELECT count(chk_id) FROM check_infos WHERE chk_id=NEW.chk_id AND key=NEW.key) = 0 THEN
        RETURN NEW;
    END IF;
    UPDATE check_infos SET value=NEW.value WHERE key=NEW.key AND chk_id=NEW.chk_id;
    RETURN OLD;
END;
$$
    LANGUAGE plpgsql;

CREATE FUNCTION object_infos_insert_fn() RETURNS "trigger"
    AS $$BEGIN
    if (SELECT count(obj_id) FROM object_infos WHERE obj_id=NEW.obj_id AND key=NEW.key) = 0 THEN
        RETURN NEW;
    END IF;
    UPDATE object_infos SET value=NEW.value WHERE key=NEW.key AND obj_id=NEW.obj_id;
    RETURN OLD;
END;
$$
    LANGUAGE plpgsql;

CREATE FUNCTION status_infos_insert_fn() RETURNS "trigger"
    AS $$BEGIN
    if (SELECT count(status_id) FROM status_infos WHERE status_id=NEW.status_id AND key=NEW.key) = 0 THEN
        RETURN NEW;
    END IF;
    UPDATE status_infos SET value=NEW.value WHERE key=NEW.key AND status_id=NEW.status_id;
    RETURN OLD;
END;
$$
    LANGUAGE plpgsql;

ALTER FUNCTION spv.check_infos_insert_fn() OWNER TO spv;
ALTER FUNCTION spv.object_infos_insert_fn() OWNER TO spv;
ALTER FUNCTION spv.status_infos_insert_fn() OWNER TO spv;

CREATE TRIGGER check_infos_insert_trg
    BEFORE INSERT ON check_infos
    FOR EACH ROW
    EXECUTE PROCEDURE check_infos_insert_fn();

CREATE TRIGGER object_infos_insert_trg
    BEFORE INSERT ON object_infos
    FOR EACH ROW
    EXECUTE PROCEDURE object_infos_insert_fn();

CREATE TRIGGER status_infos_insert_trg
    BEFORE INSERT ON status_infos
    FOR EACH ROW
    EXECUTE PROCEDURE status_infos_insert_fn();

