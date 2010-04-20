--
-- Update schema from to spvd-0.6
-- Note: django administration interface may require additional priviledges (webengine user).
-- Note: other CommonDB applications may require additional priviledges (tvr user).
--

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

CREATE ROLE spv WITH PASSWORD 'spv';
ALTER ROLE spv WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN;
ALTER ROLE spv SET search_path TO spv, pg_catalog;

ALTER SCHEMA spv OWNER TO spv;
SET search_path = spv, pg_catalog;

--
-- Name: update_modif_date(); Type: FUNCTION; Schema: spv; Owner: spv
--

CREATE FUNCTION update_modif_date() RETURNS "trigger"
    AS $$
BEGIN
    NEW.modification_date = now();
    RETURN NEW;
END$$
    LANGUAGE plpgsql SECURITY DEFINER;


ALTER FUNCTION spv.update_modif_date() OWNER TO spv;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: check_infos; Type: TABLE; Schema: spv; Owner: spv; Tablespace:
--

CREATE TABLE check_infos (
    cinfo_id integer DEFAULT nextval(('spv.check_infos_cinfo_id_seq'::text)::regclass) NOT NULL,
    chk_id integer NOT NULL,
    key character varying(4096) NOT NULL,
    value character varying(4096),
    creation_date timestamp without time zone DEFAULT now(),
    modification_date timestamp without time zone DEFAULT now()
);


ALTER TABLE spv.check_infos OWNER TO spv;

--
-- Name: check_infos_cinfo_id_seq; Type: SEQUENCE; Schema: spv; Owner: spv
--

CREATE SEQUENCE check_infos_cinfo_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE spv.check_infos_cinfo_id_seq OWNER TO spv;

--
-- Name: object_infos; Type: TABLE; Schema: spv; Owner: spv; Tablespace:
--

CREATE TABLE object_infos (
    oinfo_id integer DEFAULT nextval(('spv.object_infos_oinfo_id_seq'::text)::regclass) NOT NULL,
    obj_id integer NOT NULL,
    key character varying(4096) NOT NULL,
    value character varying(4096),
    creation_date timestamp without time zone DEFAULT now(),
    modification_date timestamp without time zone DEFAULT now()
);


ALTER TABLE spv.object_infos OWNER TO spv;

--
-- Name: object_infos_oinfo_id_seq; Type: SEQUENCE; Schema: spv; Owner: spv
--

CREATE SEQUENCE object_infos_oinfo_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE spv.object_infos_oinfo_id_seq OWNER TO spv;

--
-- Name: status_infos; Type: TABLE; Schema: spv; Owner: spv; Tablespace:
--

CREATE TABLE status_infos (
    sinfo_id integer DEFAULT nextval(('spv.status_infos_sinfo_id_seq'::text)::regclass) NOT NULL,
    status_id integer NOT NULL,
    key character varying(4096) NOT NULL,
    value character varying(4096),
    creation_date timestamp without time zone DEFAULT now(),
    modification_date timestamp without time zone DEFAULT now()
);


ALTER TABLE spv.status_infos OWNER TO spv;

--
-- Name: status_infos_sinfo_id_seq; Type: SEQUENCE; Schema: spv; Owner: spv
--

CREATE SEQUENCE status_infos_sinfo_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE spv.status_infos_sinfo_id_seq OWNER TO spv;

--
-- Name: check_infos_check_key_uniq; Type: CONSTRAINT; Schema: spv; Owner: spv; Tablespace:
--

ALTER TABLE ONLY check_infos
    ADD CONSTRAINT check_infos_check_key_uniq UNIQUE (chk_id, key);

--
-- Name: cinfo_id_pkey; Type: CONSTRAINT; Schema: spv; Owner: spv; Tablespace:
--

ALTER TABLE ONLY check_infos
    ADD CONSTRAINT cinfo_id_pkey PRIMARY KEY (cinfo_id);

--
-- Name: object_infos_object_key_uniq; Type: CONSTRAINT; Schema: spv; Owner: spv; Tablespace:
--

ALTER TABLE ONLY object_infos
    ADD CONSTRAINT object_infos_object_key_uniq UNIQUE (obj_id, key);

--
-- Name: oinfo_id_pkey; Type: CONSTRAINT; Schema: spv; Owner: spv; Tablespace:
--

ALTER TABLE ONLY object_infos
    ADD CONSTRAINT oinfo_id_pkey PRIMARY KEY (oinfo_id);

--
-- Name: sinfo_id_pkey; Type: CONSTRAINT; Schema: spv; Owner: spv; Tablespace:
--

ALTER TABLE ONLY status_infos
    ADD CONSTRAINT sinfo_id_pkey PRIMARY KEY (sinfo_id);

--
-- Name: status_infos_status_key_uniq; Type: CONSTRAINT; Schema: spv; Owner: spv; Tablespace:
--

ALTER TABLE ONLY status_infos
    ADD CONSTRAINT status_infos_status_key_uniq UNIQUE (status_id, key);

--
-- Name: check_infos_update_modif_date; Type: TRIGGER; Schema: spv; Owner: spv
--

CREATE TRIGGER check_infos_update_modif_date
    BEFORE UPDATE ON check_infos
    FOR EACH ROW
    EXECUTE PROCEDURE update_modif_date();

--
-- Name: object_infos_update_modif_date; Type: TRIGGER; Schema: spv; Owner: spv
--

CREATE TRIGGER object_infos_update_modif_date
    BEFORE UPDATE ON object_infos
    FOR EACH ROW
    EXECUTE PROCEDURE update_modif_date();

--
-- Name: status_infos_update_modif_date; Type: TRIGGER; Schema: spv; Owner: spv
--

CREATE TRIGGER status_infos_update_modif_date
    BEFORE UPDATE ON status_infos
    FOR EACH ROW
    EXECUTE PROCEDURE update_modif_date();

--
-- Name: check_infos_chk_id_fk; Type: FK CONSTRAINT; Schema: spv; Owner: spv
--

ALTER TABLE ONLY check_infos
    ADD CONSTRAINT check_infos_chk_id_fk FOREIGN KEY (chk_id) REFERENCES checks(chk_id) ON DELETE CASCADE;

--
-- Name: object_infos_obj_id_fk; Type: FK CONSTRAINT; Schema: spv; Owner: spv
--

ALTER TABLE ONLY object_infos
    ADD CONSTRAINT object_infos_obj_id_fk FOREIGN KEY (obj_id) REFERENCES objects(obj_id) ON DELETE CASCADE;

--
-- Name: status_infos_status_id_fk; Type: FK CONSTRAINT; Schema: spv; Owner: spv
--

ALTER TABLE ONLY status_infos
    ADD CONSTRAINT status_infos_status_id_fk FOREIGN KEY (status_id) REFERENCES status(status_id) ON DELETE CASCADE;


--
-- Name: spv; Type: ACL; Schema: -; Owner: spv
--

REVOKE ALL ON SCHEMA spv FROM PUBLIC;
REVOKE ALL ON SCHEMA spv FROM spv;
GRANT ALL ON SCHEMA spv TO spv;

--
-- Name: check_infos; Type: ACL; Schema: spv; Owner: spv
--

REVOKE ALL ON TABLE check_infos FROM PUBLIC;
REVOKE ALL ON TABLE check_infos FROM spv;
GRANT ALL ON TABLE check_infos TO spv;

--
-- Name: checks; Type: ACL; Schema: spv; Owner: spv
--

REVOKE ALL ON TABLE checks FROM PUBLIC;
REVOKE ALL ON TABLE checks FROM spv;
GRANT ALL ON TABLE checks TO spv;

--
-- Name: checks_group; Type: ACL; Schema: spv; Owner: spv
--

REVOKE ALL ON TABLE checks_group FROM PUBLIC;
REVOKE ALL ON TABLE checks_group FROM spv;
GRANT ALL ON TABLE checks_group TO spv;

--
-- Name: groups; Type: ACL; Schema: spv; Owner: spv
--

REVOKE ALL ON TABLE groups FROM PUBLIC;
REVOKE ALL ON TABLE groups FROM spv;
GRANT ALL ON TABLE groups TO spv;

--
-- Name: objects; Type: ACL; Schema: spv; Owner: spv
--

REVOKE ALL ON TABLE objects FROM PUBLIC;
REVOKE ALL ON TABLE objects FROM spv;
GRANT ALL ON TABLE objects TO spv;

--
-- Name: objects_group; Type: ACL; Schema: spv; Owner: spv
--

REVOKE ALL ON TABLE objects_group FROM PUBLIC;
REVOKE ALL ON TABLE objects_group FROM spv;
GRANT ALL ON TABLE objects_group TO spv;

--
-- Name: status; Type: ACL; Schema: spv; Owner: spv
--

REVOKE ALL ON TABLE status FROM PUBLIC;
REVOKE ALL ON TABLE status FROM spv;
GRANT ALL ON TABLE status TO spv;

--
-- Name: checks_list; Type: ACL; Schema: spv; Owner: spv
--

REVOKE ALL ON TABLE checks_list FROM PUBLIC;
REVOKE ALL ON TABLE checks_list FROM spv;
GRANT ALL ON TABLE checks_list TO spv;
