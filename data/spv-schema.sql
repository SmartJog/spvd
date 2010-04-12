SET client_encoding = 'UTF8';
SET check_function_bodies = false;
SET client_min_messages = warning;
SET default_tablespace = '';
SET default_with_oids = false;
SET escape_string_warning = off;
SET standard_conforming_strings = off;
SET statement_timeout = 0;

CREATE ROLE spv WITH PASSWORD 'spv';
ALTER ROLE spv WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN;
ALTER ROLE spv SET search_path TO spv, pg_catalog;

CREATE SCHEMA spv;
ALTER SCHEMA spv OWNER TO spv;
GRANT ALL ON SCHEMA spv to spv;
COMMENT ON SCHEMA spv IS 'Supervision schema';
CREATE PROCEDURAL LANGUAGE plpgsql;
ALTER PROCEDURAL LANGUAGE plpgsql OWNER TO postgres;
SET search_path = spv, pg_catalog;


CREATE SEQUENCE checks_chk_id_seq           START WITH 1 INCREMENT BY 1 NO MAXVALUE NO MINVALUE CACHE 1;
CREATE SEQUENCE groups_grp_id_seq           START WITH 1 INCREMENT BY 1 NO MAXVALUE NO MINVALUE CACHE 1;
CREATE SEQUENCE checks_group_cg_id_seq      START WITH 1 INCREMENT BY 1 NO MAXVALUE NO MINVALUE CACHE 1;
CREATE SEQUENCE objects_obj_id_seq          START WITH 1 INCREMENT BY 1 NO MAXVALUE NO MINVALUE CACHE 1;
CREATE SEQUENCE objects_group_og_id_seq     START WITH 1 INCREMENT BY 1 NO MAXVALUE NO MINVALUE CACHE 1;
CREATE SEQUENCE status_status_id_seq        START WITH 1 INCREMENT BY 1 NO MAXVALUE NO MINVALUE CACHE 1;
CREATE SEQUENCE check_infos_cinfo_id_seq    START WITH 1 INCREMENT BY 1 NO MAXVALUE NO MINVALUE CACHE 1;
CREATE SEQUENCE status_infos_sinfo_id_seq   START WITH 1 INCREMENT BY 1 NO MAXVALUE NO MINVALUE CACHE 1;
CREATE SEQUENCE object_infos_oinfo_id_seq   START WITH 1 INCREMENT BY 1 NO MAXVALUE NO MINVALUE CACHE 1;






CREATE FUNCTION check_insert() RETURNS trigger AS $$
BEGIN
    EXECUTE new_check(NEW.cg_id, NEW.grp_id);
    RETURN NEW;
END;$$
LANGUAGE plpgsql;



CREATE FUNCTION new_check(in_cg_id integer, in_grp_id integer) RETURNS void AS $$
DECLARE
  object RECORD;
BEGIN
  FOR object IN SELECT * FROM objects_group NATURAL JOIN groups WHERE grp_id=in_grp_id LOOP
    INSERT INTO status(cg_id,og_id,seq_id) VALUES (in_cg_id, object.og_id, 0);
  END LOOP;
END;$$
LANGUAGE plpgsql;



CREATE FUNCTION new_object(in_og_id integer, in_grp_id integer) RETURNS void AS $$
DECLARE
  check RECORD;
BEGIN
  FOR check IN SELECT * FROM checks_group NATURAL JOIN groups WHERE grp_id=in_grp_id LOOP
    INSERT INTO status(cg_id,og_id,seq_id) VALUES (check.cg_id, in_og_id, 0);
  END LOOP;
END;$$
LANGUAGE plpgsql;



CREATE FUNCTION object_insert() RETURNS trigger AS $$
BEGIN
  EXECUTE new_object(NEW.og_id, NEW.grp_id);
  RETURN NEW;
END;$$
LANGUAGE plpgsql;



CREATE FUNCTION status_get_repeat(status_id integer) RETURNS integer AS $$
DECLARE
  r INTEGER;
BEGIN
  r := repeat FROM status, checks_group, checks WHERE status.cg_id = checks_group.cg_id AND checks_group.chk_id = checks.chk_id AND status.status_id = status_id;
  RAISE DEBUG 'Repeat: (% seconds)', r;
  RETURN r;
END;$$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION status_update() RETURNS trigger AS $$DECLARE
    repeat INTEGER;
    seconds VARCHAR;
BEGIN
    IF OLD.check_status != NEW.check_status THEN
            NEW.status_changed_date=now();
    END IF;
    RETURN NEW;
END;$$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION status_get_repeat(status_id integer) RETURNS integer AS $$
DECLARE
  r INTEGER;
BEGIN
  r := repeat FROM status, checks_group, checks WHERE status.cg_id = checks_group.cg_id AND checks_group.chk_id = checks.chk_id AND status.status_id = status_id;
  RETURN r;
END;$$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION update_modif_date() RETURNS trigger AS $$
BEGIN
    NEW.modification_date = now();
    RETURN NEW;
END$$
LANGUAGE plpgsql security definer;




CREATE OR REPLACE FUNCTION insert_spv(INTEGER, character varying, character varying) RETURNS boolean AS
$BODY$
    DECLARE
        _status_id      ALIAS FOR $1;
        _key            ALIAS FOR $2;
        _value          ALIAS FOR $3;
        _sinfo_id        INTEGER;
    BEGIN
        IF _status_id IS NULL OR _key IS NULL THEN -- Allow _value to be null
            RETURN false;
        END IF;
        SELECT INTO _sinfo_id sinfo_id FROM status_infos WHERE status_id = _status_id AND "key" = _key;
        IF _sinfo_id IS NULL THEN
           INSERT INTO status_infos (status_id, key, value) VALUES (_status_id, _key, _value);
        ELSE
           UPDATE status_infos SET value = _value WHERE sinfo_id = _sinfo_id;
        END IF;
        RETURN true;
    END;
$BODY$
LANGUAGE plpgsql;





CREATE TABLE checks (
    chk_id integer DEFAULT nextval(('spv.checks_chk_id_seq'::text)::regclass) NOT NULL,
    plugin character varying NOT NULL,
    plugin_check character varying NOT NULL,
    name character varying NOT NULL,
    repeat integer NOT NULL,
    CONSTRAINT strictly_positive_time CHECK ((repeat > 0))
);

CREATE TABLE checks_group (
    cg_id integer DEFAULT nextval(('spv.checks_group_cg_id_seq'::text)::regclass) NOT NULL,
    chk_id integer NOT NULL,
    grp_id integer NOT NULL
);

CREATE TABLE groups (
    grp_id integer DEFAULT nextval(('spv.groups_grp_id_seq'::text)::regclass) NOT NULL,
    name character varying NOT NULL
);

CREATE TABLE objects (
    obj_id integer DEFAULT nextval(('spv.objects_obj_id_seq'::text)::regclass) NOT NULL,
    address character varying NOT NULL,
    type character varying(64),
    creation_date date DEFAULT now() NOT NULL,
    modification_date date
);

CREATE TABLE objects_group (
    og_id integer DEFAULT nextval(('spv.objects_group_og_id_seq'::text)::regclass) NOT NULL,
    obj_id integer NOT NULL,
    grp_id integer NOT NULL
);

CREATE TABLE status (
    status_id integer DEFAULT nextval(('spv.status_status_id_seq'::text)::regclass) NOT NULL,
    cg_id integer NOT NULL,
    og_id integer NOT NULL,
    check_status character varying,
    check_message character varying,
    last_check timestamp without time zone DEFAULT now(),
    next_check timestamp without time zone DEFAULT now(),
    status_acknowledged_date timestamp without time zone default now(),
    status_changed_date timestamp without time zone default now(),
    seq_id integer DEFAULT 0 NOT NULL,
    CONSTRAINT positive_seqence CHECK ((seq_id >= 0))
);

CREATE TABLE status_infos (
    sinfo_id integer DEFAULT nextval(('spv.status_infos_sinfo_id_seq'::text)::regclass) NOT NULL,
    status_id integer NOT NULL,
    key character varying(4096) NOT NULL,
    value character varying(4096),
    creation_date timestamp without time zone DEFAULT now(),
    modification_date timestamp without time zone DEFAULT now()
);

CREATE TABLE object_infos (
    oinfo_id integer DEFAULT nextval(('spv.object_infos_oinfo_id_seq'::text)::regclass) NOT NULL,
    obj_id integer NOT NULL,
    key character varying(4096) NOT NULL,
    value character varying(4096),
    creation_date timestamp without time zone DEFAULT now(),
    modification_date timestamp without time zone DEFAULT now()
);

CREATE TABLE check_infos (
    cinfo_id integer DEFAULT nextval(('spv.check_infos_cinfo_id_seq'::text)::regclass) NOT NULL,
    chk_id integer NOT NULL,
    key character varying(4096) NOT NULL,
    value character varying(4096),
    creation_date timestamp without time zone DEFAULT now(),
    modification_date timestamp without time zone DEFAULT now()
);


CREATE OR REPLACE VIEW checks_list AS SELECT checks.plugin_check, checks.plugin, groups.grp_id, status.last_check, status.next_check, status.check_status, status.check_message, status.cg_id, status.og_id, status.seq_id, status.status_id, objects.address, groups.name AS group_name, checks.name AS check_name FROM objects NATURAL JOIN objects_group NATURAL JOIN status NATURAL JOIN checks_group NATURAL JOIN checks left JOIN groups ON (checks_group.grp_id=groups.grp_id);
CREATE OR REPLACE VIEW status_infos_view AS SELECT * FROM status_infos;
CREATE OR REPLACE RULE status_infos_view_rule AS ON INSERT TO status_infos_view DO INSTEAD SELECT insert_spv (NEW.status_id, NEW.key, NEW.value);

COMMENT ON COLUMN groups.name IS 'User visible string';
COMMENT ON COLUMN status.last_check IS 'When was the check last fetched';
COMMENT ON COLUMN status.next_check IS 'When will the check be performed again';
COMMENT ON COLUMN checks.name IS 'User visible string';

ALTER TABLE ONLY checks         ADD CONSTRAINT chk_id_pkey PRIMARY KEY (chk_id);
ALTER TABLE ONLY checks         ADD CONSTRAINT plugin_checks_unique UNIQUE (plugin, plugin_check, name);
ALTER TABLE ONLY checks_group   ADD CONSTRAINT chk_id_fk FOREIGN KEY (chk_id) REFERENCES checks(chk_id) ON DELETE CASCADE;
ALTER TABLE ONLY checks_group   ADD CONSTRAINT cg_id_pkey PRIMARY KEY (cg_id);
ALTER TABLE ONLY checks_group   ADD CONSTRAINT checks_group_uniq_key UNIQUE (cg_id, chk_id, grp_id);
ALTER TABLE ONLY groups         ADD CONSTRAINT grp_id_pkey PRIMARY KEY (grp_id);
ALTER TABLE ONLY object_infos   ADD CONSTRAINT object_infos_object_key_uniq UNIQUE (obj_id, key);
ALTER TABLE ONLY object_infos   ADD CONSTRAINT oinfo_id_pkey PRIMARY KEY (oinfo_id);
ALTER TABLE ONLY objects        ADD CONSTRAINT obj_id_pkey PRIMARY KEY (obj_id);
ALTER TABLE ONLY objects        ADD CONSTRAINT uniq_address UNIQUE (address);
ALTER TABLE ONLY objects_group  ADD CONSTRAINT grp_id_fk FOREIGN KEY (grp_id) REFERENCES groups(grp_id) ON DELETE CASCADE;
ALTER TABLE ONLY objects_group  ADD CONSTRAINT obj_id_fk FOREIGN KEY (obj_id) REFERENCES objects(obj_id) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE ONLY objects_group  ADD CONSTRAINT objects_group_uniq_key UNIQUE (og_id, obj_id, grp_id);
ALTER TABLE ONLY objects_group  ADD CONSTRAINT og_id_pkey PRIMARY KEY (og_id);
ALTER TABLE ONLY status         ADD CONSTRAINT cg_id_fk FOREIGN KEY (cg_id) REFERENCES checks_group(cg_id) ON DELETE CASCADE;
ALTER TABLE ONLY status         ADD CONSTRAINT og_id_fk FOREIGN KEY (og_id) REFERENCES objects_group(og_id) ON DELETE CASCADE;
ALTER TABLE ONLY status         ADD CONSTRAINT status_id_pkey PRIMARY KEY (status_id);
ALTER TABLE ONLY status         ADD CONSTRAINT status_uniq_key UNIQUE (status_id, cg_id, og_id);
ALTER TABLE ONLY status_infos   ADD CONSTRAINT sinfo_id_pkey PRIMARY KEY (sinfo_id);
ALTER TABLE ONLY status_infos   ADD CONSTRAINT status_infos_status_id_fk FOREIGN KEY (status_id) REFERENCES status(status_id) ON DELETE CASCADE;
ALTER TABLE ONLY status_infos   ADD CONSTRAINT status_infos_status_key_uniq UNIQUE (status_id, key);
ALTER TABLE ONLY check_infos    ADD CONSTRAINT check_infos_check_key_uniq UNIQUE (chk_id, key);
ALTER TABLE ONLY check_infos    ADD CONSTRAINT check_infos_chk_id_fk FOREIGN KEY (chk_id) REFERENCES checks(chk_id) ON DELETE CASCADE;
ALTER TABLE ONLY check_infos    ADD CONSTRAINT cinfo_id_pkey PRIMARY KEY (cinfo_id);
ALTER TABLE ONLY checks_group   ADD CONSTRAINT grp_id_fk FOREIGN KEY (grp_id) REFERENCES groups(grp_id) ON DELETE CASCADE;
ALTER TABLE ONLY object_infos   ADD CONSTRAINT object_infos_obj_id_fk FOREIGN KEY (obj_id) REFERENCES objects(obj_id) ON DELETE CASCADE;

CREATE TRIGGER checks_group_insert AFTER INSERT ON checks_group FOR EACH ROW EXECUTE PROCEDURE check_insert();
CREATE TRIGGER objects_group_insert AFTER INSERT ON objects_group FOR EACH ROW EXECUTE PROCEDURE object_insert();
CREATE TRIGGER status_update_trigger BEFORE UPDATE ON status FOR EACH ROW EXECUTE PROCEDURE status_update();
CREATE TRIGGER status_infos_update_modif_date BEFORE UPDATE ON spv.status_infos FOR EACH ROW EXECUTE PROCEDURE update_modif_date();
CREATE TRIGGER object_infos_update_modif_date BEFORE UPDATE ON spv.object_infos FOR EACH ROW EXECUTE PROCEDURE spv.update_modif_date();
CREATE TRIGGER check_infos_update_modif_date BEFORE UPDATE ON spv.check_infos FOR EACH ROW EXECUTE PROCEDURE spv.update_modif_date();

ALTER TABLE spv.check_infos_cinfo_id_seq    OWNER TO spv;
ALTER TABLE spv.object_infos_oinfo_id_seq   OWNER TO spv;
ALTER TABLE spv.checks                      OWNER TO spv;
ALTER TABLE spv.checks_chk_id_seq           OWNER TO spv;
ALTER TABLE spv.checks_group                OWNER TO spv;
ALTER TABLE spv.checks_group_cg_id_seq      OWNER TO spv;
ALTER TABLE spv.checks_list                 OWNER TO spv;
ALTER TABLE spv.groups                      OWNER TO spv;
ALTER TABLE spv.groups_grp_id_seq           OWNER TO spv;
ALTER TABLE spv.objects                     OWNER TO spv;
ALTER TABLE spv.objects_group               OWNER TO spv;
ALTER TABLE spv.objects_group_og_id_seq     OWNER TO spv;
ALTER TABLE spv.objects_obj_id_seq          OWNER TO spv;
ALTER TABLE spv.status                      OWNER TO spv;
ALTER TABLE spv.status_infos                OWNER TO spv;
ALTER TABLE spv.status_infos_view           OWNER TO spv;
ALTER TABLE spv.status_status_id_seq        OWNER TO spv;
ALTER TABLE status_infos_sinfo_id_seq       OWNER TO spv;
ALTER TABLE spv.object_infos                OWNER TO spv;
ALTER TABLE spv.check_infos                 OWNER TO spv;

ALTER FUNCTION spv.check_insert()                                   OWNER TO spv;
ALTER FUNCTION spv.new_check(in_cg_id integer, in_grp_id integer)   OWNER TO spv;
ALTER FUNCTION spv.new_object(in_og_id integer, in_grp_id integer)  OWNER TO spv;
ALTER FUNCTION spv.object_insert()                                  OWNER TO spv;
ALTER FUNCTION spv.status_get_repeat(status_id integer)             OWNER TO spv;
ALTER FUNCTION spv.status_update()                                  OWNER TO spv;

GRANT ALL ON SCHEMA spv                 TO webengine;
GRANT ALL ON check_infos                TO webengine;
GRANT ALL ON check_infos_cinfo_id_seq   TO webengine;
GRANT ALL ON checks                     TO webengine;
GRANT ALL ON checks_chk_id_seq          TO webengine;
GRANT ALL ON checks_group               TO webengine;
GRANT ALL ON checks_group_cg_id_seq     TO webengine;
GRANT ALL ON groups                     TO webengine;
GRANT ALL ON groups_grp_id_seq          TO webengine;
GRANT ALL ON object_infos               TO webengine;
GRANT ALL ON object_infos_oinfo_id_seq  TO webengine;
GRANT ALL ON objects                    TO webengine;
GRANT ALL ON objects_group              TO webengine;
GRANT ALL ON objects_group_og_id_seq    TO webengine;
GRANT ALL ON objects_obj_id_seq         TO webengine;
GRANT ALL ON status                     TO webengine;
GRANT ALL ON status_infos               TO webengine;
GRANT ALL ON status_infos_sinfo_id_seq  TO webengine;
GRANT ALL ON status_status_id_seq       TO webengine;

ALTER USER webengine set search_path = spv, public, webengine;
