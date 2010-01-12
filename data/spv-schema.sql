--
-- PostgreSQL database dump
--

SET client_encoding = 'UTF8';
SET check_function_bodies = false;
SET client_min_messages = warning;
SET default_tablespace = '';
SET default_with_oids = false;
SET escape_string_warning = off;
SET standard_conforming_strings = off;
SET statement_timeout = 0;

--
-- Role: sjspv
--

CREATE ROLE sjspv WITH PASSWORD 'sjspv';
ALTER ROLE sjspv WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN;
ALTER ROLE sjspv SET search_path TO spv, pg_catalog;

--
-- Name: spv; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA spv;


ALTER SCHEMA spv OWNER TO sjspv;
GRANT ALL ON SCHEMA spv to sjspv;

--
-- Name: SCHEMA spv; Type: COMMENT; Schema: -; Owner: sjspv
--

COMMENT ON SCHEMA spv IS 'Supervision schema';


--
-- Name: plpgsql; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: postgres
--

CREATE PROCEDURAL LANGUAGE plpgsql;


ALTER PROCEDURAL LANGUAGE plpgsql OWNER TO postgres;

SET search_path = spv, pg_catalog;

--
-- Name: check_insert(); Type: FUNCTION; Schema: spv; Owner: postgres
--

CREATE FUNCTION check_insert() RETURNS trigger
    AS $$BEGIN

  EXECUTE new_check(NEW.cg_id, NEW.grp_id);

  RETURN NEW;

END;$$
    LANGUAGE plpgsql;

ALTER FUNCTION spv.check_insert() OWNER TO sjspv;

--
-- Name: new_check(integer, integer); Type: FUNCTION; Schema: spv; Owner: sjspv
--

CREATE FUNCTION new_check(in_cg_id integer, in_grp_id integer) RETURNS void
    AS $$DECLARE

  object RECORD;

BEGIN

  FOR object IN SELECT * FROM objects_group NATURAL JOIN groups WHERE grp_id=in_grp_id LOOP

    INSERT INTO status(cg_id,og_id,seq_id) VALUES (in_cg_id, object.og_id, 0);

  END LOOP;

END;$$
    LANGUAGE plpgsql;


ALTER FUNCTION spv.new_check(in_cg_id integer, in_grp_id integer) OWNER TO sjspv;

--
-- Name: new_object(integer, integer); Type: FUNCTION; Schema: spv; Owner: sjspv
--

CREATE FUNCTION new_object(in_og_id integer, in_grp_id integer) RETURNS void
    AS $$DECLARE

  check RECORD;

BEGIN

  FOR check IN SELECT * FROM checks_group NATURAL JOIN groups WHERE grp_id=in_grp_id LOOP

    INSERT INTO status(cg_id,og_id,seq_id) VALUES (check.cg_id, in_og_id, 0);

  END LOOP;

END;$$
    LANGUAGE plpgsql;


ALTER FUNCTION spv.new_object(in_og_id integer, in_grp_id integer) OWNER TO sjspv;

--
-- Name: object_insert(); Type: FUNCTION; Schema: spv; Owner: sjspv
--

CREATE FUNCTION object_insert() RETURNS trigger
    AS $$BEGIN

  EXECUTE new_object(NEW.og_id, NEW.grp_id);

  RETURN NEW;

END;$$
    LANGUAGE plpgsql;

ALTER FUNCTION spv.object_insert() OWNER TO sjspv;

--
-- Name: status_get_repeat(integer); Type: FUNCTION; Schema: spv; Owner: sjspv
--

CREATE FUNCTION status_get_repeat(status_id integer) RETURNS integer
    AS $$DECLARE

  r INTEGER;

BEGIN

  r := repeat FROM status, checks_group, checks WHERE status.cg_id = checks_group.cg_id AND checks_group.chk_id = checks.chk_id AND status.status_id = status_id;

  RAISE DEBUG 'Repeat: (% seconds)', r;

  RETURN r;

END;$$
    LANGUAGE plpgsql;


ALTER FUNCTION spv.status_get_repeat(status_id integer) OWNER TO sjspv;

--
-- Name: status_update(); Type: FUNCTION; Schema: spv; Owner: postgres
--

CREATE FUNCTION status_update() RETURNS trigger
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

  RETURN NEW;

END;$$
    LANGUAGE plpgsql;


ALTER FUNCTION spv.status_update() OWNER TO sjspv;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: checks; Type: TABLE; Schema: spv; Owner: sjspv; Tablespace:
--

CREATE TABLE checks (
    chk_id integer DEFAULT nextval(('spv.checks_increment'::text)::regclass) NOT NULL,
    plugin character varying NOT NULL,
    plugin_check character varying NOT NULL,
    name character varying NOT NULL,
    repeat integer NOT NULL,
    CONSTRAINT strictly_positive_time CHECK ((repeat > 0))
);


ALTER TABLE spv.checks OWNER TO sjspv;

--
-- Name: COLUMN checks.name; Type: COMMENT; Schema: spv; Owner: sjspv
--

COMMENT ON COLUMN checks.name IS 'User visible string';


--
-- Name: checks_group; Type: TABLE; Schema: spv; Owner: postgres; Tablespace:
--

CREATE TABLE checks_group (
    cg_id integer DEFAULT nextval(('spv.checks_group_increment'::text)::regclass) NOT NULL,
    chk_id integer NOT NULL,
    grp_id integer NOT NULL
);


ALTER TABLE spv.checks_group OWNER TO sjspv;

--
-- Name: checks_group_increment; Type: SEQUENCE; Schema: spv; Owner: postgres
--

CREATE SEQUENCE checks_group_increment
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;
ALTER TABLE spv.checks_group_increment OWNER TO sjspv;

--
-- Name: checks_increment; Type: SEQUENCE; Schema: spv; Owner: postgres
--

CREATE SEQUENCE checks_increment
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE spv.checks_increment OWNER TO sjspv;

--
-- Name: groups; Type: TABLE; Schema: spv; Owner: postgres; Tablespace:
--

CREATE TABLE groups (
    grp_id integer DEFAULT nextval(('spv.groups_increment'::text)::regclass) NOT NULL,
    name character varying NOT NULL
);

ALTER TABLE spv.groups OWNER TO sjspv;

--
-- Name: COLUMN groups.name; Type: COMMENT; Schema: spv; Owner: postgres
--

COMMENT ON COLUMN groups.name IS 'User visible string';


--
-- Name: objects; Type: TABLE; Schema: spv; Owner: postgres; Tablespace:
--

CREATE TABLE objects (
    obj_id integer DEFAULT nextval(('spv.objects_increment'::text)::regclass) NOT NULL,
    address character varying NOT NULL,
    creation_date date DEFAULT now() NOT NULL,
    modification_date date
);


ALTER TABLE spv.objects OWNER TO sjspv;

--
-- Name: objects_group; Type: TABLE; Schema: spv; Owner: postgres; Tablespace:
--

CREATE TABLE objects_group (
    og_id integer DEFAULT nextval(('spv.objects_group_increment'::text)::regclass) NOT NULL,
    obj_id integer NOT NULL,
    grp_id integer NOT NULL
);


ALTER TABLE spv.objects_group OWNER TO sjspv;

--
-- Name: status; Type: TABLE; Schema: spv; Owner: sjspv; Tablespace:
--

CREATE TABLE status (
    status_id integer DEFAULT nextval(('spv.status_increment'::text)::regclass) NOT NULL,
    cg_id integer NOT NULL,
    og_id integer NOT NULL,
    check_status character varying,
    check_message character varying,
    last_check timestamp without time zone DEFAULT now(),
    next_check timestamp without time zone DEFAULT now(),
    seq_id integer DEFAULT 0 NOT NULL,
    CONSTRAINT positive_seqence CHECK ((seq_id >= 0)),
    CONSTRAINT time_is_coherent CHECK ((((last_check IS NULL) AND (next_check IS NULL)) OR (next_check >= last_check)))
);


ALTER TABLE spv.status OWNER TO sjspv;

--
-- Name: COLUMN status.last_check; Type: COMMENT; Schema: spv; Owner: sjspv
--

COMMENT ON COLUMN status.last_check IS 'When was the check last fetched';


--
-- Name: COLUMN status.next_check; Type: COMMENT; Schema: spv; Owner: sjspv
--

COMMENT ON COLUMN status.next_check IS 'When will the check be performed again';


--
-- Name: checks_list; Type: VIEW; Schema: spv; Owner: sjspv
--


CREATE OR REPLACE VIEW checks_list AS SELECT checks.plugin_check, checks.plugin, groups.grp_id, status.last_check, status.next_check, status.check_status, status.check_message, status.cg_id, status.og_id, status.seq_id, status.status_id, objects.address, groups.name AS group_name, checks.name AS check_name FROM objects NATURAL JOIN objects_group NATURAL JOIN status NATURAL JOIN checks_group NATURAL JOIN checks left JOIN groups ON (checks_group.grp_id=groups.grp_id); 



ALTER TABLE spv.checks_list OWNER TO sjspv;

--
-- Name: groups_increment; Type: SEQUENCE; Schema: spv; Owner: sjspv
--

CREATE SEQUENCE groups_increment
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE spv.groups_increment OWNER TO sjspv;

--
-- Name: objects_group_increment; Type: SEQUENCE; Schema: spv; Owner: sjspv
--

CREATE SEQUENCE objects_group_increment
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE spv.objects_group_increment OWNER TO sjspv;

--
-- Name: objects_increment; Type: SEQUENCE; Schema: spv; Owner: sjspv
--

CREATE SEQUENCE objects_increment
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE spv.objects_increment OWNER TO sjspv;

--
-- Name: status_increment; Type: SEQUENCE; Schema: spv; Owner: sjspv
--

CREATE SEQUENCE status_increment
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE spv.status_increment OWNER TO sjspv;

SET search_path = spv, pg_catalog;

--
-- Name: cg_id_pkey; Type: CONSTRAINT; Schema: spv; Owner: postgres; Tablespace:
--

ALTER TABLE ONLY checks_group
    ADD CONSTRAINT cg_id_pkey PRIMARY KEY (cg_id);


--
-- Name: checks_group_uniq_key; Type: CONSTRAINT; Schema: spv; Owner: postgres; Tablespace:
--

ALTER TABLE ONLY checks_group
    ADD CONSTRAINT checks_group_uniq_key UNIQUE (cg_id, chk_id, grp_id);


--
-- Name: chk_id_pkey; Type: CONSTRAINT; Schema: spv; Owner: sjspv; Tablespace:
--

ALTER TABLE ONLY checks
    ADD CONSTRAINT chk_id_pkey PRIMARY KEY (chk_id);


--
-- Name: grp_id_pkey; Type: CONSTRAINT; Schema: spv; Owner: postgres; Tablespace:
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT grp_id_pkey PRIMARY KEY (grp_id);


--
-- Name: obj_id_pkey; Type: CONSTRAINT; Schema: spv; Owner: postgres; Tablespace:
--

ALTER TABLE ONLY objects
    ADD CONSTRAINT obj_id_pkey PRIMARY KEY (obj_id);


--
-- Name: objects_group_uniq_key; Type: CONSTRAINT; Schema: spv; Owner: postgres; Tablespace:
--

ALTER TABLE ONLY objects_group
    ADD CONSTRAINT objects_group_uniq_key UNIQUE (og_id, obj_id, grp_id);


--
-- Name: og_id_pkey; Type: CONSTRAINT; Schema: spv; Owner: postgres; Tablespace:
--

ALTER TABLE ONLY objects_group
    ADD CONSTRAINT og_id_pkey PRIMARY KEY (og_id);


--
-- Name: plugin_checks_unique; Type: CONSTRAINT; Schema: spv; Owner: sjspv; Tablespace:
--

ALTER TABLE ONLY checks
    ADD CONSTRAINT plugin_checks_unique UNIQUE (plugin, plugin_check);


--
-- Name: status_id_pkey; Type: CONSTRAINT; Schema: spv; Owner: postgres; Tablespace:
--

ALTER TABLE ONLY status
    ADD CONSTRAINT status_id_pkey PRIMARY KEY (status_id);


--
-- Name: status_uniq_key; Type: CONSTRAINT; Schema: spv; Owner: postgres; Tablespace:
--

ALTER TABLE ONLY status
    ADD CONSTRAINT status_uniq_key UNIQUE (status_id, cg_id, og_id);


--
-- Name: uniq_address; Type: CONSTRAINT; Schema: spv; Owner: postgres; Tablespace:
--

ALTER TABLE ONLY objects
    ADD CONSTRAINT uniq_address UNIQUE (address);


SET search_path = spv, pg_catalog;

--
-- Name: checks_group_insert; Type: TRIGGER; Schema: spv; Owner: sjspv
--

CREATE TRIGGER checks_group_insert
    AFTER INSERT ON checks_group
    FOR EACH ROW
    EXECUTE PROCEDURE check_insert();


--
-- Name: objects_group_insert; Type: TRIGGER; Schema: spv; Owner: sjspv
--

CREATE TRIGGER objects_group_insert
    AFTER INSERT ON objects_group
    FOR EACH ROW
    EXECUTE PROCEDURE object_insert();


--
-- Name: status_update_trigger; Type: TRIGGER; Schema: spv; Owner: postgres
--

CREATE TRIGGER status_update_trigger
    BEFORE UPDATE ON status
    FOR EACH ROW
    EXECUTE PROCEDURE status_update();


SET search_path = spv, pg_catalog;

--
-- Name: cg_id_fk; Type: FK CONSTRAINT; Schema: spv; Owner: postgres
--

ALTER TABLE ONLY status
    ADD CONSTRAINT cg_id_fk FOREIGN KEY (cg_id) REFERENCES checks_group(cg_id) ON DELETE CASCADE;


--
-- Name: chk_id_fk; Type: FK CONSTRAINT; Schema: spv; Owner: postgres
--

ALTER TABLE ONLY checks_group
    ADD CONSTRAINT chk_id_fk FOREIGN KEY (chk_id) REFERENCES checks(chk_id) ON DELETE CASCADE;


--
-- Name: grp_id_fk; Type: FK CONSTRAINT; Schema: spv; Owner: postgres
--

ALTER TABLE ONLY checks_group
    ADD CONSTRAINT grp_id_fk FOREIGN KEY (grp_id) REFERENCES groups(grp_id) ON DELETE CASCADE;


--
-- Name: grp_id_fk; Type: FK CONSTRAINT; Schema: spv; Owner: postgres
--

ALTER TABLE ONLY objects_group
    ADD CONSTRAINT grp_id_fk FOREIGN KEY (grp_id) REFERENCES groups(grp_id) ON DELETE CASCADE;


--
-- Name: obj_id_fk; Type: FK CONSTRAINT; Schema: spv; Owner: postgres
--

ALTER TABLE ONLY objects_group
    ADD CONSTRAINT obj_id_fk FOREIGN KEY (obj_id) REFERENCES objects(obj_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: og_id_fk; Type: FK CONSTRAINT; Schema: spv; Owner: postgres
--

ALTER TABLE ONLY status
    ADD CONSTRAINT og_id_fk FOREIGN KEY (og_id) REFERENCES objects_group(og_id) ON DELETE CASCADE;


--
-- Name: spv; Type: ACL; Schema: -; Owner: sjspv
--

REVOKE ALL ON SCHEMA spv FROM PUBLIC;
REVOKE ALL ON SCHEMA spv FROM sjspv;
GRANT ALL ON SCHEMA spv TO sjspv;


--
-- status_infos schema modification
--

CREATE OR REPLACE FUNCTION update_modif_date() RETURNS trigger AS $$
BEGIN
    NEW.modification_date = now();
    RETURN NEW;
END$$
LANGUAGE plpgsql security definer;


CREATE SEQUENCE status_infos_increment
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

ALTER TABLE status_infos_increment OWNER TO sjspv;

CREATE TABLE status_infos (
    sinfo_id integer DEFAULT nextval(('spv.status_infos_increment'::text)::regclass) NOT NULL,
    status_id integer NOT NULL,
    key character varying(4096) NOT NULL,
    value character varying(4096),
    creation_date timestamp without time zone DEFAULT now(),
    modification_date timestamp without time zone DEFAULT now()
);

ALTER TABLE ONLY status_infos
    ADD CONSTRAINT sinfo_id_pkey PRIMARY KEY (sinfo_id);

ALTER TABLE ONLY status_infos
    ADD CONSTRAINT status_infos_status_id_fk FOREIGN KEY (status_id) REFERENCES status(status_id) ON DELETE CASCADE;

ALTER TABLE ONLY status_infos
    ADD CONSTRAINT status_infos_status_key_uniq UNIQUE (status_id, key);

CREATE TRIGGER status_infos_update_modif_date BEFORE UPDATE ON spv.status_infos FOR EACH ROW EXECUTE PROCEDURE update_modif_date();

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


CREATE OR REPLACE VIEW status_infos_view AS SELECT * FROM status_infos;
CREATE OR REPLACE RULE status_infos_view_rule AS ON INSERT TO status_infos_view DO INSTEAD SELECT insert_spv (NEW.status_id, NEW.key, NEW.value);

ALTER TABLE spv.status_infos OWNER TO sjspv;
ALTER TABLE spv.status_infos_view OWNER TO sjspv;

--
-- PostgreSQL database dump complete
--

