ALTER TABLE status ADD COLUMN status_acknowledged_date timestamp without time zone;
ALTER TABLE status ADD COLUMN status_changed_date timestamp without time zone;

CREATE OR REPLACE FUNCTION status_update() RETURNS trigger
    AS $$DECLARE

  repeat INTEGER;

  seconds VARCHAR;

BEGIN

  IF OLD.last_check < NEW.last_check THEN
    repeat := status_get_repeat(NEW.status_id);
    seconds := quote_literal(repeat) || ' seconds';
    NEW.last_check := now();
    NEW.next_check := CAST (now() as TIMESTAMP) + CAST (seconds AS INTERVAL);
    RAISE DEBUG 'Last Check: (%)', NEW.last_check;
    RAISE DEBUG 'Next Check: (%)', NEW.next_check;
  END IF;
  IF OLD.check_status != NEW.check_status THEN
    NEW.status_changed_date=now();
  END IF;

  RETURN NEW;

END;$$
    LANGUAGE plpgsql;



ALTER TABLE objects ALTER obj_id SET default nextval(('spv.objects_obj_id_seq'::text)::regclass);
ALTER TABLE objects_increment RENAME TO objects_obj_id_seq;
GRANT ALL ON objects_obj_id_seq TO webengine;
GRANT ALL ON objects TO webengine;

ALTER TABLE groups ALTER grp_id SET default nextval(('spv.groups_grp_id_seq'::text)::regclass);
ALTER TABLE groups_increment RENAME TO groups_grp_id_seq;
GRANT ALL ON groups_grp_id_seq TO webengine;
GRANT ALL ON groups TO webengine;

ALTER TABLE status ALTER status_id SET default nextval(('spv.status_status_id_seq'::text)::regclass);
ALTER TABLE status_increment RENAME TO status_status_id_seq;
GRANT ALL ON status_status_id_seq TO webengine;
GRANT ALL ON status TO webengine;

ALTER TABLE checks ALTER chk_id SET default nextval(('spv.checks_chk_id_seq'::text)::regclass);
ALTER TABLE checks_increment RENAME TO checks_chk_id_seq;
GRANT ALL ON checks_chk_id_seq TO webengine;
GRANT ALL ON checks TO webengine;

ALTER TABLE objects_group ALTER og_id SET default nextval(('spv.objects_group_og_id_seq'::text)::regclass);
ALTER TABLE objects_group_increment RENAME TO objects_group_og_id_seq;
GRANT ALL ON objects_group_og_id_seq TO webengine;
GRANT ALL ON objects_group TO webengine;

ALTER TABLE checks_group ALTER cg_id SET default nextval(('spv.checks_group_cg_id_seq'::text)::regclass);
ALTER TABLE checks_group_increment RENAME TO checks_group_cg_id_seq;
GRANT ALL ON checks_group_cg_id_seq TO webengine;
GRANT ALL ON checks_group TO webengine;

ALTER TABLE status_infos ALTER sinfo_id SET default nextval(('spv.status_infos_sinfo_id_seq'::text)::regclass);
ALTER TABLE status_infos_increment RENAME TO status_infos_sinfo_id_seq;
GRANT ALL ON status_infos_sinfo_id_seq TO webengine;
GRANT ALL ON status_infos TO webengine;

CREATE OR REPLACE VIEW checks_list AS SELECT checks.plugin_check, checks.plugin, groups.grp_id, status.last_check, status.next_check, status.check_status, status.check_message, status.cg_id, status.og_id, status.seq_id, status.status_id, objects.address, groups.name AS group_name, checks.name AS check_name FROM objects NATURAL JOIN objects_group NATURAL JOIN status NATURAL JOIN checks_group NATURAL JOIN checks left JOIN groups ON (checks_group.grp_id=groups.grp_id);


GRANT ALL ON SCHEMA spv TO webengine;
GRANT ALL ON groups TO webengine;
GRANT ALL ON checks TO webengine;
GRANT ALL ON checks_group TO webengine;
GRANT ALL ON objects TO webengine;
GRANT ALL ON objects_group TO webengine;
