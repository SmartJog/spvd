--
-- PostgreSQL database dump
--

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: spv; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE spv WITH TEMPLATE = template0 ENCODING = 'UTF8';


ALTER DATABASE spv OWNER TO postgres;

\connect spv

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: plpgsql; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: postgres
--

CREATE PROCEDURAL LANGUAGE plpgsql;


ALTER PROCEDURAL LANGUAGE plpgsql OWNER TO postgres;

SET search_path = public, pg_catalog;

--
-- Name: check_insert(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION check_insert() RETURNS trigger
    AS $$BEGIN

  EXECUTE new_check(NEW.cg_id, NEW.grp_id);

  RETURN NEW;

END;$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.check_insert() OWNER TO postgres;

--
-- Name: new_check(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.new_check(in_cg_id integer, in_grp_id integer) OWNER TO postgres;

--
-- Name: new_object(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.new_object(in_og_id integer, in_grp_id integer) OWNER TO postgres;

--
-- Name: object_insert(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION object_insert() RETURNS trigger
    AS $$BEGIN

  EXECUTE new_object(NEW.og_id, NEW.grp_id);

  RETURN NEW;

END;$$
    LANGUAGE plpgsql;


ALTER FUNCTION public.object_insert() OWNER TO postgres;

--
-- Name: status_get_repeat(integer); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.status_get_repeat(status_id integer) OWNER TO postgres;

--
-- Name: status_update(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.status_update() OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: checks; Type: TABLE; Schema: public; Owner: postgres; Tablespace:
--

CREATE TABLE checks (
    chk_id integer DEFAULT nextval(('public.checks_increment'::text)::regclass) NOT NULL,
    plugin character varying NOT NULL,
    plugin_check character varying NOT NULL,
    name character varying NOT NULL,
    repeat integer NOT NULL,
    CONSTRAINT strictly_positive_time CHECK ((repeat > 0))
);


ALTER TABLE public.checks OWNER TO postgres;

--
-- Name: COLUMN checks.name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN checks.name IS 'User visible string';


--
-- Name: checks_group; Type: TABLE; Schema: public; Owner: postgres; Tablespace:
--

CREATE TABLE checks_group (
    cg_id integer DEFAULT nextval(('public.checks_group_increment'::text)::regclass) NOT NULL,
    chk_id integer NOT NULL,
    grp_id integer NOT NULL
);


ALTER TABLE public.checks_group OWNER TO postgres;

--
-- Name: checks_group_increment; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE checks_group_increment
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.checks_group_increment OWNER TO postgres;

--
-- Name: checks_increment; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE checks_increment
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.checks_increment OWNER TO postgres;

--
-- Name: groups; Type: TABLE; Schema: public; Owner: postgres; Tablespace:
--

CREATE TABLE groups (
    grp_id integer DEFAULT nextval(('public.groups_increment'::text)::regclass) NOT NULL,
    name character varying NOT NULL
);


ALTER TABLE public.groups OWNER TO postgres;

--
-- Name: COLUMN groups.name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN groups.name IS 'User visible string';


--
-- Name: objects; Type: TABLE; Schema: public; Owner: postgres; Tablespace:
--

CREATE TABLE objects (
    obj_id integer DEFAULT nextval(('public.objects_increment'::text)::regclass) NOT NULL,
    address character varying NOT NULL,
    creation_date date DEFAULT now() NOT NULL,
    modification_date date
);


ALTER TABLE public.objects OWNER TO postgres;

--
-- Name: objects_group; Type: TABLE; Schema: public; Owner: postgres; Tablespace:
--

CREATE TABLE objects_group (
    og_id integer DEFAULT nextval(('public.objects_group_increment'::text)::regclass) NOT NULL,
    obj_id integer NOT NULL,
    grp_id integer NOT NULL
);


ALTER TABLE public.objects_group OWNER TO postgres;

--
-- Name: status; Type: TABLE; Schema: public; Owner: postgres; Tablespace:
--

CREATE TABLE status (
    status_id integer DEFAULT nextval(('public.status_increment'::text)::regclass) NOT NULL,
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


ALTER TABLE public.status OWNER TO postgres;

--
-- Name: COLUMN status.last_check; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN status.last_check IS 'When was the check last fetched';


--
-- Name: COLUMN status.next_check; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN status.next_check IS 'When will the check be performed again';


--
-- Name: checks_list; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW checks_list AS
    SELECT checks.plugin_check, checks.plugin, groups.grp_id, status.last_check, status.next_check, status.check_status, status.check_message, status.cg_id, status.og_id, status.seq_id, status.status_id, objects.address, groups.name AS group_name, checks.name AS check_name FROM ((((((status JOIN objects_group ON ((status.og_id = objects_group.og_id))) JOIN objects ON ((objects_group.obj_id = objects.obj_id))) JOIN groups ON ((objects_group.grp_id = groups.grp_id))) JOIN checks_group ON ((status.cg_id = checks_group.cg_id))) JOIN checks ON ((checks_group.chk_id = checks.chk_id))) JOIN groups alias_ppa_1240585188 ON ((checks_group.grp_id = groups.grp_id)));


ALTER TABLE public.checks_list OWNER TO postgres;

--
-- Name: groups_increment; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE groups_increment
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.groups_increment OWNER TO postgres;

--
-- Name: objects_group_increment; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE objects_group_increment
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.objects_group_increment OWNER TO postgres;

--
-- Name: objects_increment; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE objects_increment
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.objects_increment OWNER TO postgres;

--
-- Name: status_increment; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE status_increment
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.status_increment OWNER TO postgres;

--
-- Name: cg_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace:
--

ALTER TABLE ONLY checks_group
    ADD CONSTRAINT cg_id_pkey PRIMARY KEY (cg_id);


--
-- Name: checks_group_uniq_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace:
--

ALTER TABLE ONLY checks_group
    ADD CONSTRAINT checks_group_uniq_key UNIQUE (cg_id, chk_id, grp_id);


--
-- Name: chk_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace:
--

ALTER TABLE ONLY checks
    ADD CONSTRAINT chk_id_pkey PRIMARY KEY (chk_id);


--
-- Name: grp_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace:
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT grp_id_pkey PRIMARY KEY (grp_id);


--
-- Name: obj_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace:
--

ALTER TABLE ONLY objects
    ADD CONSTRAINT obj_id_pkey PRIMARY KEY (obj_id);


--
-- Name: objects_group_uniq_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace:
--

ALTER TABLE ONLY objects_group
    ADD CONSTRAINT objects_group_uniq_key UNIQUE (og_id, obj_id, grp_id);


--
-- Name: og_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace:
--

ALTER TABLE ONLY objects_group
    ADD CONSTRAINT og_id_pkey PRIMARY KEY (og_id);


--
-- Name: plugin_checks_unique; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace:
--

ALTER TABLE ONLY checks
    ADD CONSTRAINT plugin_checks_unique UNIQUE (plugin, plugin_check);


--
-- Name: status_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace:
--

ALTER TABLE ONLY status
    ADD CONSTRAINT status_id_pkey PRIMARY KEY (status_id);


--
-- Name: status_uniq_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace:
--

ALTER TABLE ONLY status
    ADD CONSTRAINT status_uniq_key UNIQUE (status_id, cg_id, og_id);


--
-- Name: uniq_address; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace:
--

ALTER TABLE ONLY objects
    ADD CONSTRAINT uniq_address UNIQUE (address);


--
-- Name: checks_group_insert; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER checks_group_insert
    AFTER INSERT ON checks_group
    FOR EACH ROW
    EXECUTE PROCEDURE check_insert();


--
-- Name: objects_group_insert; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER objects_group_insert
    AFTER INSERT ON objects_group
    FOR EACH ROW
    EXECUTE PROCEDURE object_insert();


--
-- Name: status_update_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER status_update_trigger
    BEFORE UPDATE ON status
    FOR EACH ROW
    EXECUTE PROCEDURE status_update();


--
-- Name: cg_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY status
    ADD CONSTRAINT cg_id_fk FOREIGN KEY (cg_id) REFERENCES checks_group(cg_id) ON DELETE CASCADE;


--
-- Name: chk_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY checks_group
    ADD CONSTRAINT chk_id_fk FOREIGN KEY (chk_id) REFERENCES checks(chk_id) ON DELETE CASCADE;


--
-- Name: grp_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY checks_group
    ADD CONSTRAINT grp_id_fk FOREIGN KEY (grp_id) REFERENCES groups(grp_id) ON DELETE CASCADE;


--
-- Name: grp_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY objects_group
    ADD CONSTRAINT grp_id_fk FOREIGN KEY (grp_id) REFERENCES groups(grp_id) ON DELETE CASCADE;


--
-- Name: obj_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY objects_group
    ADD CONSTRAINT obj_id_fk FOREIGN KEY (obj_id) REFERENCES objects(obj_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: og_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY status
    ADD CONSTRAINT og_id_fk FOREIGN KEY (og_id) REFERENCES objects_group(og_id) ON DELETE CASCADE;


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: checks; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE checks FROM PUBLIC;
REVOKE ALL ON TABLE checks FROM postgres;
GRANT ALL ON TABLE checks TO postgres;


--
-- Name: checks_group; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE checks_group FROM PUBLIC;
REVOKE ALL ON TABLE checks_group FROM postgres;
GRANT ALL ON TABLE checks_group TO postgres;


--
-- Name: groups; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE groups FROM PUBLIC;
REVOKE ALL ON TABLE groups FROM postgres;
GRANT ALL ON TABLE groups TO postgres;


--
-- Name: objects; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE objects FROM PUBLIC;
REVOKE ALL ON TABLE objects FROM postgres;
GRANT ALL ON TABLE objects TO postgres;


--
-- Name: objects_group; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE objects_group FROM PUBLIC;
REVOKE ALL ON TABLE objects_group FROM postgres;
GRANT ALL ON TABLE objects_group TO postgres;


--
-- Name: status; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE status FROM PUBLIC;
REVOKE ALL ON TABLE status FROM postgres;
GRANT ALL ON TABLE status TO postgres;


--
-- PostgreSQL database dump complete
--

