--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: add_sys_login(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION add_sys_login(character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_sys_login_id            integer;
    v_entity_id                integer;
BEGIN
    SELECT entity_id INTO v_entity_id
    FROM entitys WHERE user_name = $1;

    v_sys_login_id := nextval('sys_logins_sys_login_id_seq');    

    INSERT INTO sys_logins (sys_login_id, entity_id)
    VALUES (v_sys_login_id, v_entity_id);

    return v_sys_login_id;
END;
$_$;


ALTER FUNCTION public.add_sys_login(character varying) OWNER TO postgres;

--
-- Name: change_password(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION change_password(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	old_password 	varchar(64);
	passchange 		varchar(120);
	entityID		integer;
BEGIN
	passchange := 'Password Error';
	entityID := CAST($1 AS INT);
	SELECT Entity_password INTO old_password
	FROM entitys WHERE (entity_id = entityID);

	IF ($2 = '0') THEN
		passchange := first_password();
		UPDATE entitys SET first_password = passchange, Entity_password = md5(passchange) WHERE (entity_id = entityID);
		passchange := 'Password Changed';
	ELSIF (old_password = md5($2)) THEN
		UPDATE entitys SET Entity_password = md5($3) WHERE (entity_id = entityID);
		passchange := 'Password Changed';
	ELSE
		passchange := null;
	END IF;

	return passchange;
END;
$_$;


ALTER FUNCTION public.change_password(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: default_currency(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION default_currency(character varying) RETURNS integer
    LANGUAGE sql
    AS $_$
	SELECT orgs.currency_id
	FROM orgs INNER JOIN entitys ON orgs.org_id = entitys.org_id
	WHERE (entitys.entity_id = CAST($1 as integer));
$_$;


ALTER FUNCTION public.default_currency(character varying) OWNER TO postgres;

--
-- Name: emailed(integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION emailed(integer, character varying) RETURNS void
    LANGUAGE sql
    AS $_$
	UPDATE sys_emailed SET emailed = true WHERE (sys_emailed_id = CAST($2 as int));
$_$;


ALTER FUNCTION public.emailed(integer, character varying) OWNER TO postgres;

--
-- Name: first_password(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION first_password() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
	rnd integer;
	passchange varchar(12);
BEGIN
	passchange := trunc(random()*1000);
	rnd := trunc(65+random()*25);
	passchange := passchange || chr(rnd);
	passchange := passchange || trunc(random()*1000);
	rnd := trunc(65+random()*25);
	passchange := passchange || chr(rnd);
	rnd := trunc(65+random()*25);
	passchange := passchange || chr(rnd);

	return passchange;
END;
$$;


ALTER FUNCTION public.first_password() OWNER TO postgres;

--
-- Name: get_currency_rate(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_currency_rate(integer, integer) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT max(exchange_rate)
	FROM currency_rates
	WHERE (org_id = $1) AND (currency_id = $2)
		AND (exchange_date = (SELECT max(exchange_date) FROM currency_rates WHERE (org_id = $1) AND (currency_id = $2)));
$_$;


ALTER FUNCTION public.get_currency_rate(integer, integer) OWNER TO postgres;

--
-- Name: get_current_year(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_current_year(character varying) RETURNS character varying
    LANGUAGE sql
    AS $$
	SELECT to_char(current_date, 'YYYY'); 
$$;


ALTER FUNCTION public.get_current_year(character varying) OWNER TO postgres;

--
-- Name: get_default_country(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_default_country(integer) RETURNS character
    LANGUAGE sql
    AS $_$
	SELECT default_country_id::varchar(2)
	FROM orgs
	WHERE (org_id = $1);
$_$;


ALTER FUNCTION public.get_default_country(integer) OWNER TO postgres;

--
-- Name: get_default_currency(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_default_currency(integer) RETURNS integer
    LANGUAGE sql
    AS $_$
	SELECT currency_id
	FROM orgs
	WHERE (org_id = $1);
$_$;


ALTER FUNCTION public.get_default_currency(integer) OWNER TO postgres;

--
-- Name: get_end_year(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_end_year(character varying) RETURNS character varying
    LANGUAGE sql
    AS $$
	SELECT '31/12/' || to_char(current_date, 'YYYY'); 
$$;


ALTER FUNCTION public.get_end_year(character varying) OWNER TO postgres;

--
-- Name: get_et_field_name(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_et_field_name(integer) RETURNS character varying
    LANGUAGE sql
    AS $_$
	SELECT et_field_name
	FROM et_fields WHERE (et_field_id = $1);
$_$;


ALTER FUNCTION public.get_et_field_name(integer) OWNER TO postgres;

--
-- Name: get_org_logo(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_org_logo(integer) RETURNS character varying
    LANGUAGE sql
    AS $_$
	SELECT orgs.logo
	FROM orgs WHERE (orgs.org_id = $1);
$_$;


ALTER FUNCTION public.get_org_logo(integer) OWNER TO postgres;

--
-- Name: get_phase_email(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_phase_email(integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
    myrec	RECORD;
	myemail	varchar(320);
BEGIN
	myemail := null;
	FOR myrec IN SELECT entitys.primary_email
		FROM entitys INNER JOIN entity_subscriptions ON entitys.entity_id = entity_subscriptions.entity_id
		WHERE (entity_subscriptions.entity_type_id = $1) LOOP

		IF (myemail is null) THEN
			IF (myrec.primary_email is not null) THEN
				myemail := myrec.primary_email;
			END IF;
		ELSE
			IF (myrec.primary_email is not null) THEN
				myemail := myemail || ', ' || myrec.primary_email;
			END IF;
		END IF;

	END LOOP;

	RETURN myemail;
END;
$_$;


ALTER FUNCTION public.get_phase_email(integer) OWNER TO postgres;

--
-- Name: get_phase_entitys(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_phase_entitys(integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
    myrec			RECORD;
	myentitys		varchar(320);
BEGIN
	myentitys := null;
	FOR myrec IN SELECT entitys.entity_name
		FROM entitys INNER JOIN entity_subscriptions ON entitys.entity_id = entity_subscriptions.entity_id
		WHERE (entity_subscriptions.entity_type_id = $1) LOOP

		IF (myentitys is null) THEN
			IF (myrec.entity_name is not null) THEN
				myentitys := myrec.entity_name;
			END IF;
		ELSE
			IF (myrec.entity_name is not null) THEN
				myentitys := myentitys || ', ' || myrec.entity_name;
			END IF;
		END IF;

	END LOOP;

	RETURN myentitys;
END;
$_$;


ALTER FUNCTION public.get_phase_entitys(integer) OWNER TO postgres;

--
-- Name: get_phase_status(boolean, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_phase_status(boolean, boolean) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	ps		varchar(16);
BEGIN
	ps := 'Draft';
	IF ($1 = true) THEN
		ps := 'Approved';
	END IF;
	IF ($2 = true) THEN
		ps := 'Rejected';
	END IF;

	RETURN ps;
END;
$_$;


ALTER FUNCTION public.get_phase_status(boolean, boolean) OWNER TO postgres;

--
-- Name: get_reporting_list(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_reporting_list(integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
    myrec	RECORD;
	mylist	varchar(320);
BEGIN
	mylist := null;
	FOR myrec IN SELECT entitys.entity_name
		FROM reporting INNER JOIN entitys ON reporting.report_to_id = entitys.entity_id
		WHERE (reporting.primary_report = true) AND (reporting.entity_id = $1) 
	LOOP

		IF (mylist is null) THEN
			mylist := myrec.entity_name;
		ELSE
			mylist := mylist || ', ' || myrec.entity_name;
		END IF;
	END LOOP;

	RETURN mylist;
END;
$_$;


ALTER FUNCTION public.get_reporting_list(integer) OWNER TO postgres;

--
-- Name: get_start_year(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_start_year(character varying) RETURNS character varying
    LANGUAGE sql
    AS $$
	SELECT '01/01/' || to_char(current_date, 'YYYY'); 
$$;


ALTER FUNCTION public.get_start_year(character varying) OWNER TO postgres;

--
-- Name: ins_address(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_address() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_address_id		integer;
BEGIN
	SELECT address_id INTO v_address_id
	FROM address WHERE (is_default = true)
		AND (table_name = NEW.table_name) AND (table_id = NEW.table_id) AND (address_id <> NEW.address_id);

	IF(NEW.is_default is null)THEN
		NEW.is_default := false;
	END IF;

	IF(NEW.is_default = true) AND (v_address_id is not null) THEN
		RAISE EXCEPTION 'Only one default Address allowed.';
	ELSIF (NEW.is_default = false) AND (v_address_id is null) THEN
		NEW.is_default := true;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_address() OWNER TO postgres;

--
-- Name: ins_applicants(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_applicants() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_org_id				integer;
	v_entity_id				integer;
	v_entity_type_id		integer;
	v_sys_email_id			integer;
BEGIN
	IF (TG_OP = 'INSERT') THEN
		IF(NEW.entity_id IS NULL) THEN
			SELECT entity_id INTO v_entity_id
			FROM entitys
			WHERE (trim(lower(user_name)) = trim(lower(NEW.user_name)));

			IF(v_entity_id is null)THEN
				v_org_id := NEW.org_id;
				IF(v_org_id is null)THEN
					SELECT min(org_id) INTO v_org_id
					FROM orgs WHERE (is_default = true);
				END IF;

				SELECT entity_type_id INTO v_entity_type_id
				FROM entity_types
				WHERE (org_id = v_org_id) AND (use_key_id = 4);

				NEW.entity_id := nextval('entitys_entity_id_seq');

				INSERT INTO entitys (entity_id, org_id, entity_type_id, use_key_id,
					entity_name, User_name,first_password,
					primary_email,function_role)
				VALUES (NEW.entity_id, v_org_id, v_entity_type_id, 4,
					NEW.full_name,
					lower(NEW.user_name),NEW.password, lower(NEW.employee_email), 'applicant');
			ELSE
				RAISE EXCEPTION 'The username exists use a different one or reset password for the current one';
			END IF;
		END IF;

		SELECT sys_email_id INTO v_sys_email_id FROM sys_emails
		WHERE (use_type = 1) AND (org_id = NEW.org_id);

		INSERT INTO sys_emailed (sys_email_id, table_id, table_name, email_type)
		VALUES (v_sys_email_id, NEW.entity_id, 'employees', 1);
	ELSIF (TG_OP = 'UPDATE') THEN
		UPDATE entitys  SET entity_name = NEW.full_name
		WHERE entity_id = NEW.entity_id;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_applicants() OWNER TO postgres;

--
-- Name: ins_approvals(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_approvals() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	reca	RECORD;
BEGIN

	IF (NEW.forward_id is not null) THEN
		SELECT workflow_phase_id, org_entity_id, app_entity_id, approval_level, table_name, table_id INTO reca
		FROM approvals
		WHERE (approval_id = NEW.forward_id);

		NEW.workflow_phase_id := reca.workflow_phase_id;
		NEW.approval_level := reca.approval_level;
		NEW.table_name := reca.table_name;
		NEW.table_id := reca.table_id;
		NEW.approve_status := 'Completed';
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_approvals() OWNER TO postgres;

--
-- Name: ins_entitys(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_entitys() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF(NEW.entity_type_id is not null) THEN
		INSERT INTO Entity_subscriptions (org_id, entity_type_id, entity_id, subscription_level_id)
		VALUES (NEW.org_id, NEW.entity_type_id, NEW.entity_id, 0);
	END IF;

	INSERT INTO entity_values (org_id, entity_id, entity_field_id)
	SELECT NEW.org_id, NEW.entity_id, entity_field_id
	FROM entity_fields
	WHERE (org_id = NEW.org_id) AND (is_active = true);

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.ins_entitys() OWNER TO postgres;

--
-- Name: ins_entry_form(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_entry_form(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	rec 		RECORD;
	vorgid		integer;
	formName 	varchar(120);
	msg 		varchar(120);
BEGIN
	SELECT entry_form_id, org_id INTO rec
	FROM entry_forms 
	WHERE (form_id = CAST($1 as int)) AND (entity_ID = CAST($2 as int))
		AND (approve_status = 'Draft');

	SELECT form_name, org_id INTO formName, vorgid
	FROM forms WHERE (form_id = CAST($1 as int));

	IF rec.entry_form_id is null THEN
		INSERT INTO entry_forms (form_id, entity_id, org_id) 
		VALUES (CAST($1 as int), CAST($2 as int), vorgid);
		msg := 'Added Form : ' || formName;
	ELSE
		msg := 'There is an incomplete form : ' || formName;
	END IF;

	return msg;
END;
$_$;


ALTER FUNCTION public.ins_entry_form(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: ins_entry_forms(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_entry_forms() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	reca		RECORD;
BEGIN
	
	SELECT default_values, default_sub_values INTO reca
	FROM forms
	WHERE (form_id = NEW.form_id);
	
	NEW.answer := reca.default_values;
	NEW.sub_answer := reca.default_sub_values;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_entry_forms() OWNER TO postgres;

--
-- Name: ins_fields(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_fields() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_ord	integer;
BEGIN
	IF(NEW.field_order is null) THEN
		SELECT max(field_order) INTO v_ord
		FROM fields
		WHERE (form_id = NEW.form_id);

		IF (v_ord is null) THEN
			NEW.field_order := 10;
		ELSE
			NEW.field_order := v_ord + 10;
		END IF;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_fields() OWNER TO postgres;

--
-- Name: ins_password(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_password() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_entity_id		integer;
BEGIN

	SELECT entity_id INTO v_entity_id
	FROM entitys
	WHERE (trim(lower(user_name)) = trim(lower(NEW.user_name)))
		AND entity_id <> NEW.entity_id;
		
	IF(v_entity_id is not null)THEN
		RAISE EXCEPTION 'The username exists use a different one or reset password for the current one';
	END IF;

	IF(TG_OP = 'INSERT') THEN
		IF(NEW.first_password is null)THEN
			NEW.first_password := first_password();
		END IF;

		IF (NEW.entity_password is null) THEN
			NEW.entity_password := md5(NEW.first_password);
		END IF;
	ELSIF(OLD.first_password <> NEW.first_password) THEN
		NEW.Entity_password := md5(NEW.first_password);
	END IF;
	
	IF(NEW.user_name is null)THEN
		SELECT org_sufix || '.' || lower(trim(replace(NEW.entity_name, ' ', ''))) INTO NEW.user_name
		FROM orgs
		WHERE org_id = NEW.org_id;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_password() OWNER TO postgres;

--
-- Name: ins_sub_fields(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_sub_fields() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_ord	integer;
BEGIN
	IF(NEW.sub_field_order is null) THEN
		SELECT max(sub_field_order) INTO v_ord
		FROM sub_fields
		WHERE (field_id = NEW.field_id);

		IF (v_ord is null) THEN
			NEW.sub_field_order := 10;
		ELSE
			NEW.sub_field_order := v_ord + 10;
		END IF;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_sub_fields() OWNER TO postgres;

--
-- Name: ins_sys_reset(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_sys_reset() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_entity_id			integer;
	v_org_id			integer;
	v_password			varchar(32);
BEGIN
	SELECT entity_id, org_id INTO v_entity_id, v_org_id
	FROM entitys
	WHERE (lower(trim(primary_email)) = lower(trim(NEW.request_email)));

	IF(v_entity_id is not null) THEN
		v_password := upper(substring(md5(random()::text) from 3 for 9));

		UPDATE entitys SET first_password = v_password, entity_password = md5(v_password)
		WHERE entity_id = v_entity_id;

		INSERT INTO sys_emailed (org_id, sys_email_id, table_id, table_name)
		VALUES(v_org_id, 3, v_entity_id, 'entitys');
	END IF;

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.ins_sys_reset() OWNER TO postgres;

--
-- Name: upd_action(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_action() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	wfid		INTEGER;
	reca		RECORD;
	tbid		INTEGER;
	iswf		BOOLEAN;
	add_flow	BOOLEAN;
BEGIN
	add_flow := false;
	IF(TG_OP = 'INSERT')THEN
		IF (NEW.approve_status = 'Completed')THEN
			add_flow := true;
		END IF;
	ELSE
		IF(OLD.approve_status = 'Draft') AND (NEW.approve_status = 'Completed')THEN
			add_flow := true;
		END IF;
	END IF;

	IF(add_flow = true)THEN
		wfid := nextval('workflow_table_id_seq');
		NEW.workflow_table_id := wfid;

		IF(TG_OP = 'UPDATE')THEN
			IF(OLD.workflow_table_id is not null)THEN
				INSERT INTO workflow_logs (org_id, table_name, table_id, table_old_id)
				VALUES (NEW.org_id, TG_TABLE_NAME, wfid, OLD.workflow_table_id);
			END IF;
		END IF;

		FOR reca IN SELECT workflows.workflow_id, workflows.table_name, workflows.table_link_field, workflows.table_link_id
		FROM workflows INNER JOIN entity_subscriptions ON workflows.source_entity_id = entity_subscriptions.entity_type_id
		WHERE (workflows.table_name = TG_TABLE_NAME) AND (entity_subscriptions.entity_id= NEW.entity_id) LOOP
			iswf := true;
			IF(reca.table_link_field is null)THEN
				iswf := true;
			ELSE
				IF(TG_TABLE_NAME = 'entry_forms')THEN
					tbid := NEW.form_id;
				END IF;
				IF(tbid = reca.table_link_id)THEN
					iswf := true;
				END IF;
			END IF;

			IF(iswf = true)THEN
				INSERT INTO approvals (org_id, workflow_phase_id, table_name, table_id, org_entity_id, escalation_days, escalation_hours, approval_level, approval_narrative, to_be_done)
				SELECT org_id, workflow_phase_id, TG_TABLE_NAME, wfid, NEW.entity_id, escalation_days, escalation_hours, approval_level, phase_narrative, 'Approve - ' || phase_narrative
				FROM vw_workflow_entitys
				WHERE (table_name = TG_TABLE_NAME) AND (entity_id = NEW.entity_id) AND (workflow_id = reca.workflow_id)
				ORDER BY approval_level, workflow_phase_id;

				UPDATE approvals SET approve_status = 'Completed'
				WHERE (table_id = wfid) AND (approval_level = 1);
			END IF;
		END LOOP;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.upd_action() OWNER TO postgres;

--
-- Name: upd_approvals(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_approvals() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	reca	RECORD;
	wfid	integer;
	vorgid	integer;
	vnotice	boolean;
	vadvice	boolean;
BEGIN

	SELECT notice, advice, org_id INTO vnotice, vadvice, vorgid
	FROM workflow_phases
	WHERE (workflow_phase_id = NEW.workflow_phase_id);

	IF (NEW.approve_status = 'Completed') THEN
		INSERT INTO sys_emailed (table_id, table_name, email_type, org_id)
		VALUES (NEW.approval_id, TG_TABLE_NAME, 1, vorgid);
	END IF;
	IF (NEW.approve_status = 'Approved') AND (vadvice = true) AND (NEW.forward_id is null) THEN
		INSERT INTO sys_emailed (table_id, table_name, email_type, org_id)
		VALUES (NEW.approval_id, TG_TABLE_NAME, 1, vorgid);
	END IF;
	IF (NEW.approve_status = 'Approved') AND (vnotice = true) AND (NEW.forward_id is null) THEN
		INSERT INTO sys_emailed (table_id, table_name, email_type, org_id)
		VALUES (NEW.approval_id, TG_TABLE_NAME, 2, vorgid);
	END IF;

	IF(TG_OP = 'INSERT') AND (NEW.forward_id is null) THEN
		INSERT INTO approval_checklists (approval_id, checklist_id, requirement, manditory, org_id)
		SELECT NEW.approval_id, checklist_id, requirement, manditory, org_id
		FROM checklists
		WHERE (workflow_phase_id = NEW.workflow_phase_id)
		ORDER BY checklist_number;
	END IF;

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.upd_approvals() OWNER TO postgres;

--
-- Name: upd_approvals(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_approvals(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	app_id		Integer;
	reca 		RECORD;
	recb		RECORD;
	recc		RECORD;
	min_level	Integer;
	mysql		varchar(240);
	msg 		varchar(120);
BEGIN
	app_id := CAST($1 as int);
	SELECT approvals.org_id, approvals.approval_id, approvals.org_id, approvals.table_name, approvals.table_id, 
		approvals.approval_level, approvals.review_advice,
		workflow_phases.workflow_phase_id, workflow_phases.workflow_id, workflow_phases.return_level INTO reca
	FROM approvals INNER JOIN workflow_phases ON approvals.workflow_phase_id = workflow_phases.workflow_phase_id
	WHERE (approvals.approval_id = app_id);

	SELECT count(approval_checklist_id) as cl_count INTO recc
	FROM approval_checklists
	WHERE (approval_id = app_id) AND (manditory = true) AND (done = false);

	IF ($3 = '1') THEN
		UPDATE approvals SET approve_status = 'Completed', completion_date = now()
		WHERE approval_id = app_id;
		msg := 'Completed';
	ELSIF ($3 = '2') AND (recc.cl_count <> 0) THEN
		msg := 'There are manditory checklist that must be checked first.';
	ELSIF ($3 = '2') AND (recc.cl_count = 0) THEN
		UPDATE approvals SET approve_status = 'Approved', action_date = now(), app_entity_id = CAST($2 as int)
		WHERE approval_id = app_id;

		SELECT min(approvals.approval_level) INTO min_level
		FROM approvals INNER JOIN workflow_phases ON approvals.workflow_phase_id = workflow_phases.workflow_phase_id
		WHERE (approvals.table_id = reca.table_id) AND (approvals.approve_status = 'Draft')
			AND (workflow_phases.advice = false) AND (workflow_phases.notice = false);

		IF(min_level is null)THEN
			mysql := 'UPDATE ' || reca.table_name || ' SET approve_status = ' || quote_literal('Approved')
			|| ', action_date = now()'
			|| ' WHERE workflow_table_id = ' || reca.table_id;
			EXECUTE mysql;

			INSERT INTO sys_emailed (org_id, table_id, table_name, email_type)
			VALUES (reca.org_id, reca.table_id, 'vw_workflow_approvals', 1);

			FOR recb IN SELECT workflow_phase_id, advice, notice
			FROM workflow_phases
			WHERE (workflow_id = reca.workflow_id) AND (approval_level >= reca.approval_level) LOOP
				IF (recb.advice = true) or (recb.notice = true) THEN
					UPDATE approvals SET approve_status = 'Approved', action_date = now(), completion_date = now()
					WHERE (workflow_phase_id = recb.workflow_phase_id) AND (table_id = reca.table_id);
				END IF;
			END LOOP;
		ELSE
			FOR recb IN SELECT workflow_phase_id, advice, notice
			FROM workflow_phases
			WHERE (workflow_id = reca.workflow_id) AND (approval_level <= min_level) LOOP
				IF (recb.advice = true) or (recb.notice = true) THEN
					UPDATE approvals SET approve_status = 'Approved', action_date = now(), completion_date = now()
					WHERE (workflow_phase_id = recb.workflow_phase_id) 
						AND (approve_status = 'Draft') AND (table_id = reca.table_id);
				ELSE
					UPDATE approvals SET approve_status = 'Completed', completion_date = now()
					WHERE (workflow_phase_id = recb.workflow_phase_id) 
						AND (approve_status = 'Draft') AND (table_id = reca.table_id);
				END IF;
			END LOOP;
		END IF;
		msg := 'Approved';
	ELSIF ($3 = '3') THEN
		UPDATE approvals SET approve_status = 'Rejected',  action_date = now(), app_entity_id = CAST($2 as int)
		WHERE approval_id = app_id;

		mysql := 'UPDATE ' || reca.table_name || ' SET approve_status = ' || quote_literal('Rejected')
		|| ', action_date = now()'
		|| ' WHERE workflow_table_id = ' || reca.table_id;
		EXECUTE mysql;

		INSERT INTO sys_emailed (table_id, table_name, email_type, org_id)
		VALUES (reca.table_id, 'vw_workflow_approvals', 2, reca.org_id);
		msg := 'Rejected';
	ELSIF ($3 = '4') AND (reca.return_level = 0) THEN
		UPDATE approvals SET approve_status = 'Review',  action_date = now(), app_entity_id = CAST($2 as int)
		WHERE approval_id = app_id;

		mysql := 'UPDATE ' || reca.table_name || ' SET approve_status = ' || quote_literal('Draft')
		|| ', action_date = now()'
		|| ' WHERE workflow_table_id = ' || reca.table_id;
		EXECUTE mysql;

		msg := 'Forwarded for review';
	ELSIF ($3 = '4') AND (reca.return_level <> 0) THEN
		UPDATE approvals SET approve_status = 'Review',  action_date = now(), app_entity_id = CAST($2 as int)
		WHERE approval_id = app_id;

		INSERT INTO approvals (org_id, workflow_phase_id, table_name, table_id, org_entity_id, escalation_days, escalation_hours, approval_level, approval_narrative, to_be_done, approve_status)
		SELECT org_id, workflow_phase_id, reca.table_name, reca.table_id, CAST($2 as int), escalation_days, escalation_hours, approval_level, phase_narrative, reca.review_advice, 'Completed'
		FROM vw_workflow_entitys
		WHERE (workflow_id = reca.workflow_id) AND (approval_level = reca.return_level)
		ORDER BY workflow_phase_id;

		UPDATE approvals SET approve_status = 'Draft' WHERE approval_id = app_id;

		msg := 'Forwarded to owner for review';
	END IF;

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.upd_approvals(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: upd_checklist(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_checklist(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	cl_id		Integer;
	reca 		RECORD;
	recc 		RECORD;
	msg 		varchar(120);
BEGIN
	cl_id := CAST($1 as int);

	SELECT approval_checklist_id, approval_id, checklist_id, requirement, manditory, done INTO reca
	FROM approval_checklists
	WHERE (approval_checklist_id = cl_id);

	IF ($3 = '1') THEN
		UPDATE approval_checklists SET done = true WHERE (approval_checklist_id = cl_id);

		SELECT count(approval_checklist_id) as cl_count INTO recc
		FROM approval_checklists
		WHERE (approval_id = reca.approval_id) AND (manditory = true) AND (done = false);
		msg := 'Checklist done.';
	ELSIF ($3 = '2') THEN
		UPDATE approval_checklists SET done = false WHERE (approval_checklist_id = cl_id);
		msg := 'Checklist not done.';
	END IF;

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.upd_checklist(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: upd_complete_form(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_complete_form(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	msg varchar(120);
BEGIN
	IF ($3 = '1') THEN
		UPDATE entry_forms SET approve_status = 'Completed', completion_date = now()
		WHERE (entry_form_id = CAST($1 as int));
		msg := 'Completed the form';
	ELSIF ($3 = '2') THEN
		UPDATE entry_forms SET approve_status = 'Approved', action_date = now()
		WHERE (entry_form_id = CAST($1 as int));
		msg := 'Approved the form';
	ELSIF ($3 = '3') THEN
		UPDATE entry_forms SET approve_status = 'Rejected', action_date = now()
		WHERE (entry_form_id = CAST($1 as int));
		msg := 'Rejected the form';
	END IF;

	return msg;
END;
$_$;


ALTER FUNCTION public.upd_complete_form(character varying, character varying, character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: address; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE address (
    address_id integer NOT NULL,
    address_type_id integer,
    sys_country_id character(2),
    org_id integer,
    address_name character varying(120),
    table_name character varying(32),
    table_id integer,
    post_office_box character varying(50),
    postal_code character varying(12),
    premises character varying(120),
    street character varying(120),
    town character varying(50),
    phone_number character varying(150),
    extension character varying(15),
    mobile character varying(150),
    fax character varying(150),
    email character varying(120),
    website character varying(120),
    is_default boolean DEFAULT false NOT NULL,
    first_password character varying(32),
    details text
);


ALTER TABLE address OWNER TO postgres;

--
-- Name: address_address_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE address_address_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE address_address_id_seq OWNER TO postgres;

--
-- Name: address_address_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE address_address_id_seq OWNED BY address.address_id;


--
-- Name: address_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE address_types (
    address_type_id integer NOT NULL,
    org_id integer,
    address_type_name character varying(50)
);


ALTER TABLE address_types OWNER TO postgres;

--
-- Name: address_types_address_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE address_types_address_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE address_types_address_type_id_seq OWNER TO postgres;

--
-- Name: address_types_address_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE address_types_address_type_id_seq OWNED BY address_types.address_type_id;


--
-- Name: approval_checklists; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE approval_checklists (
    approval_checklist_id integer NOT NULL,
    approval_id integer NOT NULL,
    checklist_id integer NOT NULL,
    org_id integer,
    requirement text,
    manditory boolean DEFAULT false NOT NULL,
    done boolean DEFAULT false NOT NULL,
    narrative character varying(320)
);


ALTER TABLE approval_checklists OWNER TO postgres;

--
-- Name: approval_checklists_approval_checklist_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE approval_checklists_approval_checklist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE approval_checklists_approval_checklist_id_seq OWNER TO postgres;

--
-- Name: approval_checklists_approval_checklist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE approval_checklists_approval_checklist_id_seq OWNED BY approval_checklists.approval_checklist_id;


--
-- Name: approvals; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE approvals (
    approval_id integer NOT NULL,
    workflow_phase_id integer NOT NULL,
    org_entity_id integer NOT NULL,
    app_entity_id integer,
    org_id integer,
    approval_level integer DEFAULT 1 NOT NULL,
    escalation_days integer DEFAULT 0 NOT NULL,
    escalation_hours integer DEFAULT 3 NOT NULL,
    escalation_time timestamp without time zone DEFAULT now() NOT NULL,
    forward_id integer,
    table_name character varying(64),
    table_id integer,
    application_date timestamp without time zone DEFAULT now() NOT NULL,
    completion_date timestamp without time zone,
    action_date timestamp without time zone,
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    approval_narrative character varying(240),
    to_be_done text,
    what_is_done text,
    review_advice text,
    details text
);


ALTER TABLE approvals OWNER TO postgres;

--
-- Name: approvals_approval_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE approvals_approval_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE approvals_approval_id_seq OWNER TO postgres;

--
-- Name: approvals_approval_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE approvals_approval_id_seq OWNED BY approvals.approval_id;


--
-- Name: checklists; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE checklists (
    checklist_id integer NOT NULL,
    workflow_phase_id integer NOT NULL,
    org_id integer,
    checklist_number integer,
    manditory boolean DEFAULT false NOT NULL,
    requirement text,
    details text
);


ALTER TABLE checklists OWNER TO postgres;

--
-- Name: checklists_checklist_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE checklists_checklist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE checklists_checklist_id_seq OWNER TO postgres;

--
-- Name: checklists_checklist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE checklists_checklist_id_seq OWNED BY checklists.checklist_id;


--
-- Name: currency; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE currency (
    currency_id integer NOT NULL,
    currency_name character varying(50),
    currency_symbol character varying(3),
    org_id integer
);


ALTER TABLE currency OWNER TO postgres;

--
-- Name: currency_currency_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE currency_currency_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE currency_currency_id_seq OWNER TO postgres;

--
-- Name: currency_currency_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE currency_currency_id_seq OWNED BY currency.currency_id;


--
-- Name: currency_rates; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE currency_rates (
    currency_rate_id integer NOT NULL,
    currency_id integer,
    org_id integer,
    exchange_date date DEFAULT ('now'::text)::date NOT NULL,
    exchange_rate real DEFAULT 1 NOT NULL
);


ALTER TABLE currency_rates OWNER TO postgres;

--
-- Name: currency_rates_currency_rate_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE currency_rates_currency_rate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE currency_rates_currency_rate_id_seq OWNER TO postgres;

--
-- Name: currency_rates_currency_rate_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE currency_rates_currency_rate_id_seq OWNED BY currency_rates.currency_rate_id;


--
-- Name: e_fields; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE e_fields (
    e_field_id integer NOT NULL,
    et_field_id integer,
    org_id integer,
    table_code integer NOT NULL,
    table_id integer,
    e_field_value character varying(320)
);


ALTER TABLE e_fields OWNER TO postgres;

--
-- Name: e_fields_e_field_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE e_fields_e_field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE e_fields_e_field_id_seq OWNER TO postgres;

--
-- Name: e_fields_e_field_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE e_fields_e_field_id_seq OWNED BY e_fields.e_field_id;


--
-- Name: employees; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE employees (
    entity_id integer NOT NULL,
    org_id integer,
    full_name character varying(100) NOT NULL,
    user_name character varying(50) NOT NULL,
    employee_email character varying(50) NOT NULL,
    employee_phone character varying(50),
    password character varying(50),
    employee_number character varying(50),
    pin character varying(50),
    date_hired date,
    id_number character varying(50),
    verifier_phone character varying(50),
    verifier_link character varying(100),
    created timestamp without time zone DEFAULT now()
);


ALTER TABLE employees OWNER TO postgres;

--
-- Name: entity_fields; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE entity_fields (
    entity_field_id integer NOT NULL,
    org_id integer NOT NULL,
    use_type integer DEFAULT 1 NOT NULL,
    is_active boolean DEFAULT true,
    entity_field_name character varying(240),
    entity_field_source character varying(320)
);


ALTER TABLE entity_fields OWNER TO postgres;

--
-- Name: entity_fields_entity_field_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE entity_fields_entity_field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE entity_fields_entity_field_id_seq OWNER TO postgres;

--
-- Name: entity_fields_entity_field_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE entity_fields_entity_field_id_seq OWNED BY entity_fields.entity_field_id;


--
-- Name: entity_subscriptions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE entity_subscriptions (
    entity_subscription_id integer NOT NULL,
    entity_type_id integer NOT NULL,
    entity_id integer NOT NULL,
    subscription_level_id integer NOT NULL,
    org_id integer,
    details text
);


ALTER TABLE entity_subscriptions OWNER TO postgres;

--
-- Name: entity_subscriptions_entity_subscription_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE entity_subscriptions_entity_subscription_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE entity_subscriptions_entity_subscription_id_seq OWNER TO postgres;

--
-- Name: entity_subscriptions_entity_subscription_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE entity_subscriptions_entity_subscription_id_seq OWNED BY entity_subscriptions.entity_subscription_id;


--
-- Name: entity_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE entity_types (
    entity_type_id integer NOT NULL,
    use_key_id integer NOT NULL,
    org_id integer,
    entity_type_name character varying(50) NOT NULL,
    entity_role character varying(240),
    start_view character varying(120),
    group_email character varying(120),
    description text,
    details text
);


ALTER TABLE entity_types OWNER TO postgres;

--
-- Name: entity_types_entity_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE entity_types_entity_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE entity_types_entity_type_id_seq OWNER TO postgres;

--
-- Name: entity_types_entity_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE entity_types_entity_type_id_seq OWNED BY entity_types.entity_type_id;


--
-- Name: entity_values; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE entity_values (
    entity_value_id integer NOT NULL,
    entity_id integer,
    entity_field_id integer,
    org_id integer,
    entity_value character varying(240)
);


ALTER TABLE entity_values OWNER TO postgres;

--
-- Name: entity_values_entity_value_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE entity_values_entity_value_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE entity_values_entity_value_id_seq OWNER TO postgres;

--
-- Name: entity_values_entity_value_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE entity_values_entity_value_id_seq OWNED BY entity_values.entity_value_id;


--
-- Name: entitys; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE entitys (
    entity_id integer NOT NULL,
    entity_type_id integer NOT NULL,
    use_key_id integer NOT NULL,
    org_id integer NOT NULL,
    entity_name character varying(120) NOT NULL,
    user_name character varying(120) NOT NULL,
    primary_email character varying(120),
    primary_telephone character varying(50),
    super_user boolean DEFAULT false NOT NULL,
    entity_leader boolean DEFAULT false NOT NULL,
    no_org boolean DEFAULT false NOT NULL,
    function_role character varying(240),
    date_enroled timestamp without time zone DEFAULT now(),
    is_active boolean DEFAULT true,
    entity_password character varying(64) NOT NULL,
    first_password character varying(64) NOT NULL,
    new_password character varying(64),
    start_url character varying(64),
    is_picked boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE entitys OWNER TO postgres;

--
-- Name: entitys_entity_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE entitys_entity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE entitys_entity_id_seq OWNER TO postgres;

--
-- Name: entitys_entity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE entitys_entity_id_seq OWNED BY entitys.entity_id;


--
-- Name: entry_forms; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE entry_forms (
    entry_form_id integer NOT NULL,
    org_id integer,
    entity_id integer,
    form_id integer,
    entered_by_id integer,
    application_date timestamp without time zone DEFAULT now() NOT NULL,
    completion_date timestamp without time zone,
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    narrative character varying(240),
    answer text,
    sub_answer text,
    details text
);


ALTER TABLE entry_forms OWNER TO postgres;

--
-- Name: entry_forms_entry_form_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE entry_forms_entry_form_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE entry_forms_entry_form_id_seq OWNER TO postgres;

--
-- Name: entry_forms_entry_form_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE entry_forms_entry_form_id_seq OWNED BY entry_forms.entry_form_id;


--
-- Name: et_fields; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE et_fields (
    et_field_id integer NOT NULL,
    org_id integer,
    et_field_name character varying(120) NOT NULL,
    table_name character varying(64) NOT NULL,
    table_code integer NOT NULL,
    table_link integer
);


ALTER TABLE et_fields OWNER TO postgres;

--
-- Name: et_fields_et_field_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE et_fields_et_field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE et_fields_et_field_id_seq OWNER TO postgres;

--
-- Name: et_fields_et_field_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE et_fields_et_field_id_seq OWNED BY et_fields.et_field_id;


--
-- Name: fields; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE fields (
    field_id integer NOT NULL,
    org_id integer,
    form_id integer,
    field_name character varying(50),
    question text,
    field_lookup text,
    field_type character varying(25) NOT NULL,
    field_class character varying(25),
    field_bold character(1) DEFAULT '0'::bpchar NOT NULL,
    field_italics character(1) DEFAULT '0'::bpchar NOT NULL,
    field_order integer NOT NULL,
    share_line integer,
    field_size integer DEFAULT 25 NOT NULL,
    label_position character(1) DEFAULT 'L'::bpchar,
    field_fnct character varying(120),
    manditory character(1) DEFAULT '0'::bpchar NOT NULL,
    show character(1) DEFAULT '1'::bpchar,
    tab character varying(25),
    details text
);


ALTER TABLE fields OWNER TO postgres;

--
-- Name: fields_field_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE fields_field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fields_field_id_seq OWNER TO postgres;

--
-- Name: fields_field_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE fields_field_id_seq OWNED BY fields.field_id;


--
-- Name: forms; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE forms (
    form_id integer NOT NULL,
    org_id integer,
    form_name character varying(240) NOT NULL,
    form_number character varying(50),
    table_name character varying(50),
    version character varying(25),
    completed character(1) DEFAULT '0'::bpchar NOT NULL,
    is_active character(1) DEFAULT '0'::bpchar NOT NULL,
    use_key integer DEFAULT 0,
    form_header text,
    form_footer text,
    default_values text,
    details text
);


ALTER TABLE forms OWNER TO postgres;

--
-- Name: forms_form_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE forms_form_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE forms_form_id_seq OWNER TO postgres;

--
-- Name: forms_form_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE forms_form_id_seq OWNED BY forms.form_id;


--
-- Name: orgs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE orgs (
    org_id integer NOT NULL,
    currency_id integer,
    default_country_id character(2),
    parent_org_id integer,
    org_name character varying(50) NOT NULL,
    org_full_name character varying(120),
    org_sufix character varying(4) NOT NULL,
    is_default boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    logo character varying(50),
    pin character varying(50),
    pcc character varying(12),
    system_key character varying(64),
    system_identifier character varying(64),
    mac_address character varying(64),
    public_key bytea,
    license bytea,
    details text
);


ALTER TABLE orgs OWNER TO postgres;

--
-- Name: orgs_org_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE orgs_org_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE orgs_org_id_seq OWNER TO postgres;

--
-- Name: orgs_org_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE orgs_org_id_seq OWNED BY orgs.org_id;


--
-- Name: picture_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE picture_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE picture_id_seq OWNER TO postgres;

--
-- Name: reporting; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE reporting (
    reporting_id integer NOT NULL,
    entity_id integer,
    report_to_id integer,
    org_id integer,
    date_from date,
    date_to date,
    reporting_level integer DEFAULT 1 NOT NULL,
    primary_report boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    ps_reporting real,
    details text
);


ALTER TABLE reporting OWNER TO postgres;

--
-- Name: reporting_reporting_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE reporting_reporting_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE reporting_reporting_id_seq OWNER TO postgres;

--
-- Name: reporting_reporting_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE reporting_reporting_id_seq OWNED BY reporting.reporting_id;


--
-- Name: sub_fields; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sub_fields (
    sub_field_id integer NOT NULL,
    org_id integer,
    field_id integer,
    sub_field_order integer NOT NULL,
    sub_title_share character varying(120),
    sub_field_type character varying(25),
    sub_field_lookup text,
    sub_field_size integer NOT NULL,
    sub_col_spans integer DEFAULT 1 NOT NULL,
    manditory character(1) DEFAULT '0'::bpchar NOT NULL,
    show character(1) DEFAULT '1'::bpchar,
    question text
);


ALTER TABLE sub_fields OWNER TO postgres;

--
-- Name: sub_fields_sub_field_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sub_fields_sub_field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sub_fields_sub_field_id_seq OWNER TO postgres;

--
-- Name: sub_fields_sub_field_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sub_fields_sub_field_id_seq OWNED BY sub_fields.sub_field_id;


--
-- Name: subscription_levels; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE subscription_levels (
    subscription_level_id integer NOT NULL,
    org_id integer,
    subscription_level_name character varying(50),
    details text
);


ALTER TABLE subscription_levels OWNER TO postgres;

--
-- Name: subscription_levels_subscription_level_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE subscription_levels_subscription_level_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE subscription_levels_subscription_level_id_seq OWNER TO postgres;

--
-- Name: subscription_levels_subscription_level_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE subscription_levels_subscription_level_id_seq OWNED BY subscription_levels.subscription_level_id;


--
-- Name: sys_audit_details; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_audit_details (
    sys_audit_trail_id integer NOT NULL,
    old_value text
);


ALTER TABLE sys_audit_details OWNER TO postgres;

--
-- Name: sys_audit_trail; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_audit_trail (
    sys_audit_trail_id integer NOT NULL,
    user_id character varying(50) NOT NULL,
    user_ip character varying(50),
    change_date timestamp without time zone DEFAULT now() NOT NULL,
    table_name character varying(50) NOT NULL,
    record_id character varying(50) NOT NULL,
    change_type character varying(50) NOT NULL,
    narrative character varying(240)
);


ALTER TABLE sys_audit_trail OWNER TO postgres;

--
-- Name: sys_audit_trail_sys_audit_trail_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_audit_trail_sys_audit_trail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sys_audit_trail_sys_audit_trail_id_seq OWNER TO postgres;

--
-- Name: sys_audit_trail_sys_audit_trail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_audit_trail_sys_audit_trail_id_seq OWNED BY sys_audit_trail.sys_audit_trail_id;


--
-- Name: sys_continents; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_continents (
    sys_continent_id character(2) NOT NULL,
    sys_continent_name character varying(120)
);


ALTER TABLE sys_continents OWNER TO postgres;

--
-- Name: sys_countrys; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_countrys (
    sys_country_id character(2) NOT NULL,
    sys_continent_id character(2),
    sys_country_code character varying(3),
    sys_country_number character varying(3),
    sys_phone_code character varying(3),
    sys_country_name character varying(120),
    sys_currency_name character varying(50),
    sys_currency_cents character varying(50),
    sys_currency_code character varying(3),
    sys_currency_exchange real
);


ALTER TABLE sys_countrys OWNER TO postgres;

--
-- Name: sys_dashboard; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_dashboard (
    sys_dashboard_id integer NOT NULL,
    entity_id integer,
    org_id integer,
    narrative character varying(240),
    details text
);


ALTER TABLE sys_dashboard OWNER TO postgres;

--
-- Name: sys_dashboard_sys_dashboard_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_dashboard_sys_dashboard_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sys_dashboard_sys_dashboard_id_seq OWNER TO postgres;

--
-- Name: sys_dashboard_sys_dashboard_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_dashboard_sys_dashboard_id_seq OWNED BY sys_dashboard.sys_dashboard_id;


--
-- Name: sys_emailed; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_emailed (
    sys_emailed_id integer NOT NULL,
    sys_email_id integer,
    org_id integer,
    table_id integer,
    table_name character varying(50),
    email_type integer DEFAULT 1 NOT NULL,
    emailed boolean DEFAULT false NOT NULL,
    created timestamp without time zone DEFAULT now(),
    narrative character varying(240),
    mail_body text
);


ALTER TABLE sys_emailed OWNER TO postgres;

--
-- Name: sys_emailed_sys_emailed_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_emailed_sys_emailed_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sys_emailed_sys_emailed_id_seq OWNER TO postgres;

--
-- Name: sys_emailed_sys_emailed_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_emailed_sys_emailed_id_seq OWNED BY sys_emailed.sys_emailed_id;


--
-- Name: sys_emails; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_emails (
    sys_email_id integer NOT NULL,
    org_id integer,
    use_type integer DEFAULT 1 NOT NULL,
    sys_email_name character varying(50),
    default_email character varying(320),
    title character varying(240) NOT NULL,
    details text
);


ALTER TABLE sys_emails OWNER TO postgres;

--
-- Name: sys_emails_sys_email_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_emails_sys_email_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sys_emails_sys_email_id_seq OWNER TO postgres;

--
-- Name: sys_emails_sys_email_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_emails_sys_email_id_seq OWNED BY sys_emails.sys_email_id;


--
-- Name: sys_errors; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_errors (
    sys_error_id integer NOT NULL,
    sys_error character varying(240) NOT NULL,
    error_message text NOT NULL
);


ALTER TABLE sys_errors OWNER TO postgres;

--
-- Name: sys_errors_sys_error_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_errors_sys_error_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sys_errors_sys_error_id_seq OWNER TO postgres;

--
-- Name: sys_errors_sys_error_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_errors_sys_error_id_seq OWNED BY sys_errors.sys_error_id;


--
-- Name: sys_files; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_files (
    sys_file_id integer NOT NULL,
    org_id integer,
    table_id integer,
    table_name character varying(50),
    file_name character varying(320),
    file_type character varying(320),
    file_size integer,
    narrative character varying(320),
    details text
);


ALTER TABLE sys_files OWNER TO postgres;

--
-- Name: sys_files_sys_file_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_files_sys_file_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sys_files_sys_file_id_seq OWNER TO postgres;

--
-- Name: sys_files_sys_file_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_files_sys_file_id_seq OWNED BY sys_files.sys_file_id;


--
-- Name: sys_logins; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_logins (
    sys_login_id integer NOT NULL,
    entity_id integer,
    login_time timestamp without time zone DEFAULT now(),
    login_ip character varying(64),
    narrative character varying(240)
);


ALTER TABLE sys_logins OWNER TO postgres;

--
-- Name: sys_logins_sys_login_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_logins_sys_login_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sys_logins_sys_login_id_seq OWNER TO postgres;

--
-- Name: sys_logins_sys_login_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_logins_sys_login_id_seq OWNED BY sys_logins.sys_login_id;


--
-- Name: sys_menu_msg; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_menu_msg (
    sys_menu_msg_id integer NOT NULL,
    menu_id character varying(16) NOT NULL,
    menu_name character varying(50) NOT NULL,
    xml_file character varying(50) NOT NULL,
    msg text
);


ALTER TABLE sys_menu_msg OWNER TO postgres;

--
-- Name: sys_menu_msg_sys_menu_msg_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_menu_msg_sys_menu_msg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sys_menu_msg_sys_menu_msg_id_seq OWNER TO postgres;

--
-- Name: sys_menu_msg_sys_menu_msg_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_menu_msg_sys_menu_msg_id_seq OWNED BY sys_menu_msg.sys_menu_msg_id;


--
-- Name: sys_news; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_news (
    sys_news_id integer NOT NULL,
    org_id integer,
    sys_news_group integer,
    sys_news_title character varying(240) NOT NULL,
    publish boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE sys_news OWNER TO postgres;

--
-- Name: sys_news_sys_news_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_news_sys_news_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sys_news_sys_news_id_seq OWNER TO postgres;

--
-- Name: sys_news_sys_news_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_news_sys_news_id_seq OWNED BY sys_news.sys_news_id;


--
-- Name: sys_queries; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_queries (
    sys_queries_id integer NOT NULL,
    org_id integer,
    sys_query_name character varying(50),
    query_date timestamp without time zone DEFAULT now() NOT NULL,
    query_text text,
    query_params text
);


ALTER TABLE sys_queries OWNER TO postgres;

--
-- Name: sys_queries_sys_queries_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_queries_sys_queries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sys_queries_sys_queries_id_seq OWNER TO postgres;

--
-- Name: sys_queries_sys_queries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_queries_sys_queries_id_seq OWNED BY sys_queries.sys_queries_id;


--
-- Name: sys_reset; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_reset (
    sys_reset_id integer NOT NULL,
    entity_id integer,
    org_id integer,
    request_email character varying(320),
    request_time timestamp without time zone DEFAULT now(),
    login_ip character varying(64),
    narrative character varying(240)
);


ALTER TABLE sys_reset OWNER TO postgres;

--
-- Name: sys_reset_sys_reset_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_reset_sys_reset_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sys_reset_sys_reset_id_seq OWNER TO postgres;

--
-- Name: sys_reset_sys_reset_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_reset_sys_reset_id_seq OWNED BY sys_reset.sys_reset_id;


--
-- Name: tomcat_users; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW tomcat_users AS
 SELECT entitys.user_name,
    entitys.entity_password,
    entity_types.entity_role
   FROM ((entity_subscriptions
     JOIN entitys ON ((entity_subscriptions.entity_id = entitys.entity_id)))
     JOIN entity_types ON ((entity_subscriptions.entity_type_id = entity_types.entity_type_id)))
  WHERE (entitys.is_active = true);


ALTER TABLE tomcat_users OWNER TO postgres;

--
-- Name: use_keys; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE use_keys (
    use_key_id integer NOT NULL,
    use_key_name character varying(32) NOT NULL,
    use_function integer
);


ALTER TABLE use_keys OWNER TO postgres;

--
-- Name: vw_address; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_address AS
 SELECT sys_countrys.sys_country_id,
    sys_countrys.sys_country_name,
    address.address_id,
    address.org_id,
    address.address_name,
    address.table_name,
    address.table_id,
    address.post_office_box,
    address.postal_code,
    address.premises,
    address.street,
    address.town,
    address.phone_number,
    address.extension,
    address.mobile,
    address.fax,
    address.email,
    address.is_default,
    address.website,
    address.details,
    address_types.address_type_id,
    address_types.address_type_name
   FROM ((address
     JOIN sys_countrys ON ((address.sys_country_id = sys_countrys.sys_country_id)))
     LEFT JOIN address_types ON ((address.address_type_id = address_types.address_type_id)));


ALTER TABLE vw_address OWNER TO postgres;

--
-- Name: vw_address_entitys; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_address_entitys AS
 SELECT vw_address.address_id,
    vw_address.address_name,
    vw_address.table_id,
    vw_address.table_name,
    vw_address.sys_country_id,
    vw_address.sys_country_name,
    vw_address.is_default,
    vw_address.post_office_box,
    vw_address.postal_code,
    vw_address.premises,
    vw_address.street,
    vw_address.town,
    vw_address.phone_number,
    vw_address.extension,
    vw_address.mobile,
    vw_address.fax,
    vw_address.email,
    vw_address.website
   FROM vw_address
  WHERE (((vw_address.table_name)::text = 'entitys'::text) AND (vw_address.is_default = true));


ALTER TABLE vw_address_entitys OWNER TO postgres;

--
-- Name: workflows; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE workflows (
    workflow_id integer NOT NULL,
    source_entity_id integer NOT NULL,
    org_id integer,
    workflow_name character varying(240) NOT NULL,
    table_name character varying(64),
    table_link_field character varying(64),
    table_link_id integer,
    approve_email text NOT NULL,
    reject_email text NOT NULL,
    approve_file character varying(320),
    reject_file character varying(320),
    link_copy integer,
    details text
);


ALTER TABLE workflows OWNER TO postgres;

--
-- Name: vw_workflows; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_workflows AS
 SELECT entity_types.entity_type_id AS source_entity_id,
    entity_types.entity_type_name AS source_entity_name,
    workflows.workflow_id,
    workflows.org_id,
    workflows.workflow_name,
    workflows.table_name,
    workflows.table_link_field,
    workflows.table_link_id,
    workflows.approve_email,
    workflows.reject_email,
    workflows.approve_file,
    workflows.reject_file,
    workflows.details
   FROM (workflows
     JOIN entity_types ON ((workflows.source_entity_id = entity_types.entity_type_id)));


ALTER TABLE vw_workflows OWNER TO postgres;

--
-- Name: workflow_phases; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE workflow_phases (
    workflow_phase_id integer NOT NULL,
    workflow_id integer NOT NULL,
    approval_entity_id integer NOT NULL,
    org_id integer,
    approval_level integer DEFAULT 1 NOT NULL,
    return_level integer DEFAULT 1 NOT NULL,
    escalation_days integer DEFAULT 0 NOT NULL,
    escalation_hours integer DEFAULT 3 NOT NULL,
    required_approvals integer DEFAULT 1 NOT NULL,
    reporting_level integer DEFAULT 1 NOT NULL,
    use_reporting boolean DEFAULT false NOT NULL,
    advice boolean DEFAULT false NOT NULL,
    notice boolean DEFAULT false NOT NULL,
    phase_narrative character varying(240) NOT NULL,
    advice_email text,
    notice_email text,
    advice_file character varying(320),
    notice_file character varying(320),
    details text
);


ALTER TABLE workflow_phases OWNER TO postgres;

--
-- Name: vw_workflow_phases; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_workflow_phases AS
 SELECT vw_workflows.source_entity_id,
    vw_workflows.source_entity_name,
    vw_workflows.workflow_id,
    vw_workflows.workflow_name,
    vw_workflows.table_name,
    vw_workflows.table_link_field,
    vw_workflows.table_link_id,
    vw_workflows.approve_email,
    vw_workflows.reject_email,
    vw_workflows.approve_file,
    vw_workflows.reject_file,
    entity_types.entity_type_id AS approval_entity_id,
    entity_types.entity_type_name AS approval_entity_name,
    workflow_phases.workflow_phase_id,
    workflow_phases.org_id,
    workflow_phases.approval_level,
    workflow_phases.return_level,
    workflow_phases.escalation_days,
    workflow_phases.escalation_hours,
    workflow_phases.notice,
    workflow_phases.notice_email,
    workflow_phases.notice_file,
    workflow_phases.advice,
    workflow_phases.advice_email,
    workflow_phases.advice_file,
    workflow_phases.required_approvals,
    workflow_phases.use_reporting,
    workflow_phases.reporting_level,
    workflow_phases.phase_narrative,
    workflow_phases.details
   FROM ((workflow_phases
     JOIN vw_workflows ON ((workflow_phases.workflow_id = vw_workflows.workflow_id)))
     JOIN entity_types ON ((workflow_phases.approval_entity_id = entity_types.entity_type_id)));


ALTER TABLE vw_workflow_phases OWNER TO postgres;

--
-- Name: vw_approvals; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_approvals AS
 SELECT vw_workflow_phases.workflow_id,
    vw_workflow_phases.workflow_name,
    vw_workflow_phases.approve_email,
    vw_workflow_phases.reject_email,
    vw_workflow_phases.source_entity_id,
    vw_workflow_phases.source_entity_name,
    vw_workflow_phases.approval_entity_id,
    vw_workflow_phases.approval_entity_name,
    vw_workflow_phases.workflow_phase_id,
    vw_workflow_phases.approval_level,
    vw_workflow_phases.phase_narrative,
    vw_workflow_phases.return_level,
    vw_workflow_phases.required_approvals,
    vw_workflow_phases.notice,
    vw_workflow_phases.notice_email,
    vw_workflow_phases.notice_file,
    vw_workflow_phases.advice,
    vw_workflow_phases.advice_email,
    vw_workflow_phases.advice_file,
    vw_workflow_phases.use_reporting,
    approvals.approval_id,
    approvals.org_id,
    approvals.forward_id,
    approvals.table_name,
    approvals.table_id,
    approvals.completion_date,
    approvals.escalation_days,
    approvals.escalation_hours,
    approvals.escalation_time,
    approvals.application_date,
    approvals.approve_status,
    approvals.action_date,
    approvals.approval_narrative,
    approvals.to_be_done,
    approvals.what_is_done,
    approvals.review_advice,
    approvals.details,
    oe.entity_id AS org_entity_id,
    oe.entity_name AS org_entity_name,
    oe.user_name AS org_user_name,
    oe.primary_email AS org_primary_email,
    ae.entity_id AS app_entity_id,
    ae.entity_name AS app_entity_name,
    ae.user_name AS app_user_name,
    ae.primary_email AS app_primary_email
   FROM (((vw_workflow_phases
     JOIN approvals ON ((vw_workflow_phases.workflow_phase_id = approvals.workflow_phase_id)))
     JOIN entitys oe ON ((approvals.org_entity_id = oe.entity_id)))
     LEFT JOIN entitys ae ON ((approvals.app_entity_id = ae.entity_id)));


ALTER TABLE vw_approvals OWNER TO postgres;

--
-- Name: vw_approvals_entitys; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_approvals_entitys AS
 SELECT vw_workflow_phases.workflow_id,
    vw_workflow_phases.workflow_name,
    vw_workflow_phases.source_entity_id,
    vw_workflow_phases.source_entity_name,
    vw_workflow_phases.approval_entity_id,
    vw_workflow_phases.approval_entity_name,
    vw_workflow_phases.workflow_phase_id,
    vw_workflow_phases.approval_level,
    vw_workflow_phases.notice,
    vw_workflow_phases.notice_email,
    vw_workflow_phases.notice_file,
    vw_workflow_phases.advice,
    vw_workflow_phases.advice_email,
    vw_workflow_phases.advice_file,
    vw_workflow_phases.return_level,
    vw_workflow_phases.required_approvals,
    vw_workflow_phases.phase_narrative,
    vw_workflow_phases.use_reporting,
    approvals.approval_id,
    approvals.org_id,
    approvals.forward_id,
    approvals.table_name,
    approvals.table_id,
    approvals.completion_date,
    approvals.escalation_days,
    approvals.escalation_hours,
    approvals.escalation_time,
    approvals.application_date,
    approvals.approve_status,
    approvals.action_date,
    approvals.approval_narrative,
    approvals.to_be_done,
    approvals.what_is_done,
    approvals.review_advice,
    approvals.details,
    oe.entity_id AS org_entity_id,
    oe.entity_name AS org_entity_name,
    oe.user_name AS org_user_name,
    oe.primary_email AS org_primary_email,
    entitys.entity_id,
    entitys.entity_name,
    entitys.user_name,
    entitys.primary_email
   FROM ((((vw_workflow_phases
     JOIN approvals ON ((vw_workflow_phases.workflow_phase_id = approvals.workflow_phase_id)))
     JOIN entitys oe ON ((approvals.org_entity_id = oe.entity_id)))
     JOIN entity_subscriptions ON ((vw_workflow_phases.approval_entity_id = entity_subscriptions.entity_type_id)))
     JOIN entitys ON ((entity_subscriptions.entity_id = entitys.entity_id)))
  WHERE ((approvals.forward_id IS NULL) AND (vw_workflow_phases.use_reporting = false))
UNION
 SELECT vw_workflow_phases.workflow_id,
    vw_workflow_phases.workflow_name,
    vw_workflow_phases.source_entity_id,
    vw_workflow_phases.source_entity_name,
    vw_workflow_phases.approval_entity_id,
    vw_workflow_phases.approval_entity_name,
    vw_workflow_phases.workflow_phase_id,
    vw_workflow_phases.approval_level,
    vw_workflow_phases.notice,
    vw_workflow_phases.notice_email,
    vw_workflow_phases.notice_file,
    vw_workflow_phases.advice,
    vw_workflow_phases.advice_email,
    vw_workflow_phases.advice_file,
    vw_workflow_phases.return_level,
    vw_workflow_phases.required_approvals,
    vw_workflow_phases.phase_narrative,
    vw_workflow_phases.use_reporting,
    approvals.approval_id,
    approvals.org_id,
    approvals.forward_id,
    approvals.table_name,
    approvals.table_id,
    approvals.completion_date,
    approvals.escalation_days,
    approvals.escalation_hours,
    approvals.escalation_time,
    approvals.application_date,
    approvals.approve_status,
    approvals.action_date,
    approvals.approval_narrative,
    approvals.to_be_done,
    approvals.what_is_done,
    approvals.review_advice,
    approvals.details,
    oe.entity_id AS org_entity_id,
    oe.entity_name AS org_entity_name,
    oe.user_name AS org_user_name,
    oe.primary_email AS org_primary_email,
    entitys.entity_id,
    entitys.entity_name,
    entitys.user_name,
    entitys.primary_email
   FROM ((((vw_workflow_phases
     JOIN approvals ON ((vw_workflow_phases.workflow_phase_id = approvals.workflow_phase_id)))
     JOIN entitys oe ON ((approvals.org_entity_id = oe.entity_id)))
     JOIN reporting ON (((approvals.org_entity_id = reporting.entity_id) AND (vw_workflow_phases.reporting_level = reporting.reporting_level))))
     JOIN entitys ON ((reporting.report_to_id = entitys.entity_id)))
  WHERE ((((approvals.forward_id IS NULL) AND (reporting.primary_report = true)) AND (reporting.is_active = true)) AND (vw_workflow_phases.use_reporting = true));


ALTER TABLE vw_approvals_entitys OWNER TO postgres;

--
-- Name: vw_e_fields; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_e_fields AS
 SELECT orgs.org_id,
    orgs.org_name,
    et_fields.et_field_id,
    et_fields.et_field_name,
    et_fields.table_name,
    et_fields.table_link,
    e_fields.e_field_id,
    e_fields.table_code,
    e_fields.table_id,
    e_fields.e_field_value
   FROM ((e_fields
     JOIN orgs ON ((e_fields.org_id = orgs.org_id)))
     JOIN et_fields ON ((e_fields.et_field_id = et_fields.et_field_id)));


ALTER TABLE vw_e_fields OWNER TO postgres;

--
-- Name: vw_entity_address; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_entity_address AS
 SELECT vw_address.address_id,
    vw_address.address_name,
    vw_address.sys_country_id,
    vw_address.sys_country_name,
    vw_address.table_id,
    vw_address.table_name,
    vw_address.is_default,
    vw_address.post_office_box,
    vw_address.postal_code,
    vw_address.premises,
    vw_address.street,
    vw_address.town,
    vw_address.phone_number,
    vw_address.extension,
    vw_address.mobile,
    vw_address.fax,
    vw_address.email,
    vw_address.website
   FROM vw_address
  WHERE (((vw_address.table_name)::text = 'entitys'::text) AND (vw_address.is_default = true));


ALTER TABLE vw_entity_address OWNER TO postgres;

--
-- Name: vw_entity_subscriptions; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_entity_subscriptions AS
 SELECT entity_types.entity_type_id,
    entity_types.entity_type_name,
    entitys.entity_id,
    entitys.entity_name,
    subscription_levels.subscription_level_id,
    subscription_levels.subscription_level_name,
    entity_subscriptions.entity_subscription_id,
    entity_subscriptions.org_id,
    entity_subscriptions.details
   FROM (((entity_subscriptions
     JOIN entity_types ON ((entity_subscriptions.entity_type_id = entity_types.entity_type_id)))
     JOIN entitys ON ((entity_subscriptions.entity_id = entitys.entity_id)))
     JOIN subscription_levels ON ((entity_subscriptions.subscription_level_id = subscription_levels.subscription_level_id)));


ALTER TABLE vw_entity_subscriptions OWNER TO postgres;

--
-- Name: vw_entity_types; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_entity_types AS
 SELECT use_keys.use_key_id,
    use_keys.use_key_name,
    use_keys.use_function,
    entity_types.entity_type_id,
    entity_types.org_id,
    entity_types.entity_type_name,
    entity_types.entity_role,
    entity_types.start_view,
    entity_types.group_email,
    entity_types.description,
    entity_types.details
   FROM (use_keys
     JOIN entity_types ON ((use_keys.use_key_id = entity_types.use_key_id)));


ALTER TABLE vw_entity_types OWNER TO postgres;

--
-- Name: vw_entity_values; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_entity_values AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    entity_fields.entity_field_id,
    entity_fields.entity_field_name,
    entity_values.org_id,
    entity_values.entity_value_id,
    entity_values.entity_value
   FROM ((entity_values
     JOIN entitys ON ((entity_values.entity_id = entitys.entity_id)))
     JOIN entity_fields ON ((entity_values.entity_field_id = entity_fields.entity_field_id)));


ALTER TABLE vw_entity_values OWNER TO postgres;

--
-- Name: vw_org_address; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_org_address AS
 SELECT vw_address.sys_country_id AS org_sys_country_id,
    vw_address.sys_country_name AS org_sys_country_name,
    vw_address.address_id AS org_address_id,
    vw_address.table_id AS org_table_id,
    vw_address.table_name AS org_table_name,
    vw_address.post_office_box AS org_post_office_box,
    vw_address.postal_code AS org_postal_code,
    vw_address.premises AS org_premises,
    vw_address.street AS org_street,
    vw_address.town AS org_town,
    vw_address.phone_number AS org_phone_number,
    vw_address.extension AS org_extension,
    vw_address.mobile AS org_mobile,
    vw_address.fax AS org_fax,
    vw_address.email AS org_email,
    vw_address.website AS org_website
   FROM vw_address
  WHERE (((vw_address.table_name)::text = 'orgs'::text) AND (vw_address.is_default = true));


ALTER TABLE vw_org_address OWNER TO postgres;

--
-- Name: vw_orgs; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_orgs AS
 SELECT orgs.org_id,
    orgs.org_name,
    orgs.is_default,
    orgs.is_active,
    orgs.logo,
    orgs.org_full_name,
    orgs.pin,
    orgs.pcc,
    orgs.details,
    currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    vw_org_address.org_sys_country_id,
    vw_org_address.org_sys_country_name,
    vw_org_address.org_address_id,
    vw_org_address.org_table_name,
    vw_org_address.org_post_office_box,
    vw_org_address.org_postal_code,
    vw_org_address.org_premises,
    vw_org_address.org_street,
    vw_org_address.org_town,
    vw_org_address.org_phone_number,
    vw_org_address.org_extension,
    vw_org_address.org_mobile,
    vw_org_address.org_fax,
    vw_org_address.org_email,
    vw_org_address.org_website
   FROM ((orgs
     JOIN currency ON ((orgs.currency_id = currency.currency_id)))
     LEFT JOIN vw_org_address ON ((orgs.org_id = vw_org_address.org_table_id)));


ALTER TABLE vw_orgs OWNER TO postgres;

--
-- Name: vw_entitys; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_entitys AS
 SELECT vw_orgs.org_id,
    vw_orgs.org_name,
    vw_orgs.is_default AS org_is_default,
    vw_orgs.is_active AS org_is_active,
    vw_orgs.logo AS org_logo,
    vw_orgs.org_sys_country_id,
    vw_orgs.org_sys_country_name,
    vw_orgs.org_address_id,
    vw_orgs.org_table_name,
    vw_orgs.org_post_office_box,
    vw_orgs.org_postal_code,
    vw_orgs.org_premises,
    vw_orgs.org_street,
    vw_orgs.org_town,
    vw_orgs.org_phone_number,
    vw_orgs.org_extension,
    vw_orgs.org_mobile,
    vw_orgs.org_fax,
    vw_orgs.org_email,
    vw_orgs.org_website,
    vw_entity_address.address_id,
    vw_entity_address.address_name,
    vw_entity_address.sys_country_id,
    vw_entity_address.sys_country_name,
    vw_entity_address.table_name,
    vw_entity_address.is_default,
    vw_entity_address.post_office_box,
    vw_entity_address.postal_code,
    vw_entity_address.premises,
    vw_entity_address.street,
    vw_entity_address.town,
    vw_entity_address.phone_number,
    vw_entity_address.extension,
    vw_entity_address.mobile,
    vw_entity_address.fax,
    vw_entity_address.email,
    vw_entity_address.website,
    entity_types.entity_type_id,
    entity_types.entity_type_name,
    entity_types.entity_role,
    entitys.entity_id,
    entitys.entity_name,
    entitys.user_name,
    entitys.super_user,
    entitys.entity_leader,
    entitys.date_enroled,
    entitys.is_active,
    entitys.entity_password,
    entitys.first_password,
    entitys.function_role,
    entitys.use_key_id,
    entitys.primary_email,
    entitys.primary_telephone
   FROM (((entitys
     LEFT JOIN vw_entity_address ON ((entitys.entity_id = vw_entity_address.table_id)))
     JOIN vw_orgs ON ((entitys.org_id = vw_orgs.org_id)))
     JOIN entity_types ON ((entitys.entity_type_id = entity_types.entity_type_id)));


ALTER TABLE vw_entitys OWNER TO postgres;

--
-- Name: vw_entry_forms; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_entry_forms AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    forms.form_id,
    forms.form_name,
    forms.form_number,
    forms.completed,
    forms.is_active,
    forms.use_key,
    entry_forms.org_id,
    entry_forms.entry_form_id,
    entry_forms.approve_status,
    entry_forms.application_date,
    entry_forms.completion_date,
    entry_forms.action_date,
    entry_forms.narrative,
    entry_forms.answer,
    entry_forms.workflow_table_id,
    entry_forms.details
   FROM ((entry_forms
     JOIN entitys ON ((entry_forms.entity_id = entitys.entity_id)))
     JOIN forms ON ((entry_forms.form_id = forms.form_id)));


ALTER TABLE vw_entry_forms OWNER TO postgres;

--
-- Name: vw_fields; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_fields AS
 SELECT forms.form_id,
    forms.form_name,
    fields.field_id,
    fields.org_id,
    fields.question,
    fields.field_lookup,
    fields.field_type,
    fields.field_order,
    fields.share_line,
    fields.field_size,
    fields.field_fnct,
    fields.manditory,
    fields.field_bold,
    fields.field_italics
   FROM (fields
     JOIN forms ON ((fields.form_id = forms.form_id)));


ALTER TABLE vw_fields OWNER TO postgres;

--
-- Name: vw_org_select; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_org_select AS
 SELECT orgs.org_id,
    orgs.parent_org_id,
    orgs.org_name
   FROM orgs
  WHERE ((orgs.is_active = true) AND (orgs.org_id <> orgs.parent_org_id))
UNION
 SELECT orgs.org_id,
    orgs.org_id AS parent_org_id,
    orgs.org_name
   FROM orgs
  WHERE (orgs.is_active = true);


ALTER TABLE vw_org_select OWNER TO postgres;

--
-- Name: vw_reporting; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_reporting AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    rpt.entity_id AS rpt_id,
    rpt.entity_name AS rpt_name,
    reporting.org_id,
    reporting.reporting_id,
    reporting.date_from,
    reporting.date_to,
    reporting.primary_report,
    reporting.is_active,
    reporting.ps_reporting,
    reporting.reporting_level,
    reporting.details
   FROM ((reporting
     JOIN entitys ON ((reporting.entity_id = entitys.entity_id)))
     JOIN entitys rpt ON ((reporting.report_to_id = rpt.entity_id)));


ALTER TABLE vw_reporting OWNER TO postgres;

--
-- Name: vw_sub_fields; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_sub_fields AS
 SELECT vw_fields.form_id,
    vw_fields.form_name,
    vw_fields.field_id,
    sub_fields.sub_field_id,
    sub_fields.org_id,
    sub_fields.sub_field_order,
    sub_fields.sub_title_share,
    sub_fields.sub_field_type,
    sub_fields.sub_field_lookup,
    sub_fields.sub_field_size,
    sub_fields.sub_col_spans,
    sub_fields.manditory,
    sub_fields.question
   FROM (sub_fields
     JOIN vw_fields ON ((sub_fields.field_id = vw_fields.field_id)));


ALTER TABLE vw_sub_fields OWNER TO postgres;

--
-- Name: vw_sys_countrys; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_sys_countrys AS
 SELECT sys_continents.sys_continent_id,
    sys_continents.sys_continent_name,
    sys_countrys.sys_country_id,
    sys_countrys.sys_country_code,
    sys_countrys.sys_country_number,
    sys_countrys.sys_phone_code,
    sys_countrys.sys_country_name
   FROM (sys_continents
     JOIN sys_countrys ON ((sys_continents.sys_continent_id = sys_countrys.sys_continent_id)));


ALTER TABLE vw_sys_countrys OWNER TO postgres;

--
-- Name: vw_sys_emailed; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_sys_emailed AS
 SELECT sys_emails.sys_email_id,
    sys_emails.org_id,
    sys_emails.sys_email_name,
    sys_emails.title,
    sys_emails.details,
    sys_emailed.sys_emailed_id,
    sys_emailed.table_id,
    sys_emailed.table_name,
    sys_emailed.email_type,
    sys_emailed.emailed,
    sys_emailed.narrative
   FROM (sys_emails
     RIGHT JOIN sys_emailed ON ((sys_emails.sys_email_id = sys_emailed.sys_email_id)));


ALTER TABLE vw_sys_emailed OWNER TO postgres;

--
-- Name: vw_workflow_approvals; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_workflow_approvals AS
 SELECT vw_approvals.workflow_id,
    vw_approvals.org_id,
    vw_approvals.workflow_name,
    vw_approvals.approve_email,
    vw_approvals.reject_email,
    vw_approvals.source_entity_id,
    vw_approvals.source_entity_name,
    vw_approvals.table_name,
    vw_approvals.table_id,
    vw_approvals.org_entity_id,
    vw_approvals.org_entity_name,
    vw_approvals.org_user_name,
    vw_approvals.org_primary_email,
    rt.rejected_count,
        CASE
            WHEN (rt.rejected_count IS NULL) THEN ((vw_approvals.workflow_name)::text || ' Approved'::text)
            ELSE ((vw_approvals.workflow_name)::text || ' declined'::text)
        END AS workflow_narrative
   FROM (vw_approvals
     LEFT JOIN ( SELECT approvals.table_id,
            count(approvals.approval_id) AS rejected_count
           FROM approvals
          WHERE (((approvals.approve_status)::text = 'Rejected'::text) AND (approvals.forward_id IS NULL))
          GROUP BY approvals.table_id) rt ON ((vw_approvals.table_id = rt.table_id)))
  GROUP BY vw_approvals.workflow_id, vw_approvals.org_id, vw_approvals.workflow_name, vw_approvals.approve_email, vw_approvals.reject_email, vw_approvals.source_entity_id, vw_approvals.source_entity_name, vw_approvals.table_name, vw_approvals.table_id, vw_approvals.org_entity_id, vw_approvals.org_entity_name, vw_approvals.org_user_name, vw_approvals.org_primary_email, rt.rejected_count;


ALTER TABLE vw_workflow_approvals OWNER TO postgres;

--
-- Name: vw_workflow_entitys; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_workflow_entitys AS
 SELECT vw_workflow_phases.workflow_id,
    vw_workflow_phases.org_id,
    vw_workflow_phases.workflow_name,
    vw_workflow_phases.table_name,
    vw_workflow_phases.table_link_id,
    vw_workflow_phases.source_entity_id,
    vw_workflow_phases.source_entity_name,
    vw_workflow_phases.approval_entity_id,
    vw_workflow_phases.approval_entity_name,
    vw_workflow_phases.workflow_phase_id,
    vw_workflow_phases.approval_level,
    vw_workflow_phases.return_level,
    vw_workflow_phases.escalation_days,
    vw_workflow_phases.escalation_hours,
    vw_workflow_phases.notice,
    vw_workflow_phases.notice_email,
    vw_workflow_phases.notice_file,
    vw_workflow_phases.advice,
    vw_workflow_phases.advice_email,
    vw_workflow_phases.advice_file,
    vw_workflow_phases.required_approvals,
    vw_workflow_phases.use_reporting,
    vw_workflow_phases.phase_narrative,
    entity_subscriptions.entity_subscription_id,
    entity_subscriptions.entity_id,
    entity_subscriptions.subscription_level_id
   FROM (vw_workflow_phases
     JOIN entity_subscriptions ON ((vw_workflow_phases.source_entity_id = entity_subscriptions.entity_type_id)));


ALTER TABLE vw_workflow_entitys OWNER TO postgres;

--
-- Name: workflow_sql; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE workflow_sql (
    workflow_sql_id integer NOT NULL,
    workflow_phase_id integer NOT NULL,
    org_id integer,
    workflow_sql_name character varying(50),
    is_condition boolean DEFAULT false,
    is_action boolean DEFAULT false,
    message text NOT NULL,
    sql text NOT NULL
);


ALTER TABLE workflow_sql OWNER TO postgres;

--
-- Name: vw_workflow_sql; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_workflow_sql AS
 SELECT workflow_sql.org_id,
    workflow_sql.workflow_sql_id,
    workflow_sql.workflow_phase_id,
    workflow_sql.workflow_sql_name,
    workflow_sql.is_condition,
    workflow_sql.is_action,
    workflow_sql.message,
    workflow_sql.sql,
    approvals.approval_id,
    approvals.org_entity_id,
    approvals.app_entity_id,
    approvals.approval_level,
    approvals.escalation_days,
    approvals.escalation_hours,
    approvals.escalation_time,
    approvals.forward_id,
    approvals.table_name,
    approvals.table_id,
    approvals.application_date,
    approvals.completion_date,
    approvals.action_date,
    approvals.approve_status,
    approvals.approval_narrative
   FROM (workflow_sql
     JOIN approvals ON ((workflow_sql.workflow_phase_id = approvals.workflow_phase_id)));


ALTER TABLE vw_workflow_sql OWNER TO postgres;

--
-- Name: workflow_logs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE workflow_logs (
    workflow_log_id integer NOT NULL,
    org_id integer,
    table_name character varying(64),
    table_id integer,
    table_old_id integer
);


ALTER TABLE workflow_logs OWNER TO postgres;

--
-- Name: workflow_logs_workflow_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE workflow_logs_workflow_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE workflow_logs_workflow_log_id_seq OWNER TO postgres;

--
-- Name: workflow_logs_workflow_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE workflow_logs_workflow_log_id_seq OWNED BY workflow_logs.workflow_log_id;


--
-- Name: workflow_phases_workflow_phase_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE workflow_phases_workflow_phase_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE workflow_phases_workflow_phase_id_seq OWNER TO postgres;

--
-- Name: workflow_phases_workflow_phase_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE workflow_phases_workflow_phase_id_seq OWNED BY workflow_phases.workflow_phase_id;


--
-- Name: workflow_sql_workflow_sql_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE workflow_sql_workflow_sql_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE workflow_sql_workflow_sql_id_seq OWNER TO postgres;

--
-- Name: workflow_sql_workflow_sql_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE workflow_sql_workflow_sql_id_seq OWNED BY workflow_sql.workflow_sql_id;


--
-- Name: workflow_table_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE workflow_table_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE workflow_table_id_seq OWNER TO postgres;

--
-- Name: workflows_workflow_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE workflows_workflow_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE workflows_workflow_id_seq OWNER TO postgres;

--
-- Name: workflows_workflow_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE workflows_workflow_id_seq OWNED BY workflows.workflow_id;


--
-- Name: address_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address ALTER COLUMN address_id SET DEFAULT nextval('address_address_id_seq'::regclass);


--
-- Name: address_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address_types ALTER COLUMN address_type_id SET DEFAULT nextval('address_types_address_type_id_seq'::regclass);


--
-- Name: approval_checklist_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approval_checklists ALTER COLUMN approval_checklist_id SET DEFAULT nextval('approval_checklists_approval_checklist_id_seq'::regclass);


--
-- Name: approval_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approvals ALTER COLUMN approval_id SET DEFAULT nextval('approvals_approval_id_seq'::regclass);


--
-- Name: checklist_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY checklists ALTER COLUMN checklist_id SET DEFAULT nextval('checklists_checklist_id_seq'::regclass);


--
-- Name: currency_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY currency ALTER COLUMN currency_id SET DEFAULT nextval('currency_currency_id_seq'::regclass);


--
-- Name: currency_rate_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY currency_rates ALTER COLUMN currency_rate_id SET DEFAULT nextval('currency_rates_currency_rate_id_seq'::regclass);


--
-- Name: e_field_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY e_fields ALTER COLUMN e_field_id SET DEFAULT nextval('e_fields_e_field_id_seq'::regclass);


--
-- Name: entity_field_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_fields ALTER COLUMN entity_field_id SET DEFAULT nextval('entity_fields_entity_field_id_seq'::regclass);


--
-- Name: entity_subscription_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_subscriptions ALTER COLUMN entity_subscription_id SET DEFAULT nextval('entity_subscriptions_entity_subscription_id_seq'::regclass);


--
-- Name: entity_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_types ALTER COLUMN entity_type_id SET DEFAULT nextval('entity_types_entity_type_id_seq'::regclass);


--
-- Name: entity_value_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_values ALTER COLUMN entity_value_id SET DEFAULT nextval('entity_values_entity_value_id_seq'::regclass);


--
-- Name: entity_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entitys ALTER COLUMN entity_id SET DEFAULT nextval('entitys_entity_id_seq'::regclass);


--
-- Name: entry_form_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entry_forms ALTER COLUMN entry_form_id SET DEFAULT nextval('entry_forms_entry_form_id_seq'::regclass);


--
-- Name: et_field_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY et_fields ALTER COLUMN et_field_id SET DEFAULT nextval('et_fields_et_field_id_seq'::regclass);


--
-- Name: field_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY fields ALTER COLUMN field_id SET DEFAULT nextval('fields_field_id_seq'::regclass);


--
-- Name: form_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY forms ALTER COLUMN form_id SET DEFAULT nextval('forms_form_id_seq'::regclass);


--
-- Name: org_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs ALTER COLUMN org_id SET DEFAULT nextval('orgs_org_id_seq'::regclass);


--
-- Name: reporting_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reporting ALTER COLUMN reporting_id SET DEFAULT nextval('reporting_reporting_id_seq'::regclass);


--
-- Name: sub_field_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sub_fields ALTER COLUMN sub_field_id SET DEFAULT nextval('sub_fields_sub_field_id_seq'::regclass);


--
-- Name: subscription_level_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY subscription_levels ALTER COLUMN subscription_level_id SET DEFAULT nextval('subscription_levels_subscription_level_id_seq'::regclass);


--
-- Name: sys_audit_trail_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_audit_trail ALTER COLUMN sys_audit_trail_id SET DEFAULT nextval('sys_audit_trail_sys_audit_trail_id_seq'::regclass);


--
-- Name: sys_dashboard_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_dashboard ALTER COLUMN sys_dashboard_id SET DEFAULT nextval('sys_dashboard_sys_dashboard_id_seq'::regclass);


--
-- Name: sys_emailed_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_emailed ALTER COLUMN sys_emailed_id SET DEFAULT nextval('sys_emailed_sys_emailed_id_seq'::regclass);


--
-- Name: sys_email_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_emails ALTER COLUMN sys_email_id SET DEFAULT nextval('sys_emails_sys_email_id_seq'::regclass);


--
-- Name: sys_error_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_errors ALTER COLUMN sys_error_id SET DEFAULT nextval('sys_errors_sys_error_id_seq'::regclass);


--
-- Name: sys_file_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_files ALTER COLUMN sys_file_id SET DEFAULT nextval('sys_files_sys_file_id_seq'::regclass);


--
-- Name: sys_login_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_logins ALTER COLUMN sys_login_id SET DEFAULT nextval('sys_logins_sys_login_id_seq'::regclass);


--
-- Name: sys_menu_msg_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_menu_msg ALTER COLUMN sys_menu_msg_id SET DEFAULT nextval('sys_menu_msg_sys_menu_msg_id_seq'::regclass);


--
-- Name: sys_news_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_news ALTER COLUMN sys_news_id SET DEFAULT nextval('sys_news_sys_news_id_seq'::regclass);


--
-- Name: sys_queries_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_queries ALTER COLUMN sys_queries_id SET DEFAULT nextval('sys_queries_sys_queries_id_seq'::regclass);


--
-- Name: sys_reset_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_reset ALTER COLUMN sys_reset_id SET DEFAULT nextval('sys_reset_sys_reset_id_seq'::regclass);


--
-- Name: workflow_log_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_logs ALTER COLUMN workflow_log_id SET DEFAULT nextval('workflow_logs_workflow_log_id_seq'::regclass);


--
-- Name: workflow_phase_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_phases ALTER COLUMN workflow_phase_id SET DEFAULT nextval('workflow_phases_workflow_phase_id_seq'::regclass);


--
-- Name: workflow_sql_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_sql ALTER COLUMN workflow_sql_id SET DEFAULT nextval('workflow_sql_workflow_sql_id_seq'::regclass);


--
-- Name: workflow_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflows ALTER COLUMN workflow_id SET DEFAULT nextval('workflows_workflow_id_seq'::regclass);


--
-- Data for Name: address; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY address (address_id, address_type_id, sys_country_id, org_id, address_name, table_name, table_id, post_office_box, postal_code, premises, street, town, phone_number, extension, mobile, fax, email, website, is_default, first_password, details) FROM stdin;
\.


--
-- Name: address_address_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('address_address_id_seq', 1, false);


--
-- Data for Name: address_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY address_types (address_type_id, org_id, address_type_name) FROM stdin;
\.


--
-- Name: address_types_address_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('address_types_address_type_id_seq', 1, false);


--
-- Data for Name: approval_checklists; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY approval_checklists (approval_checklist_id, approval_id, checklist_id, org_id, requirement, manditory, done, narrative) FROM stdin;
\.


--
-- Name: approval_checklists_approval_checklist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('approval_checklists_approval_checklist_id_seq', 1, false);


--
-- Data for Name: approvals; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY approvals (approval_id, workflow_phase_id, org_entity_id, app_entity_id, org_id, approval_level, escalation_days, escalation_hours, escalation_time, forward_id, table_name, table_id, application_date, completion_date, action_date, approve_status, approval_narrative, to_be_done, what_is_done, review_advice, details) FROM stdin;
\.


--
-- Name: approvals_approval_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('approvals_approval_id_seq', 1, false);


--
-- Data for Name: checklists; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY checklists (checklist_id, workflow_phase_id, org_id, checklist_number, manditory, requirement, details) FROM stdin;
\.


--
-- Name: checklists_checklist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('checklists_checklist_id_seq', 1, false);


--
-- Data for Name: currency; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY currency (currency_id, currency_name, currency_symbol, org_id) FROM stdin;
1	Kenya Shillings	KES	0
2	US Dollar	USD	0
3	British Pound	BPD	0
4	Euro	ERO	0
\.


--
-- Name: currency_currency_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('currency_currency_id_seq', 4, true);


--
-- Data for Name: currency_rates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY currency_rates (currency_rate_id, currency_id, org_id, exchange_date, exchange_rate) FROM stdin;
0	1	0	2018-01-09	1
\.


--
-- Name: currency_rates_currency_rate_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('currency_rates_currency_rate_id_seq', 1, false);


--
-- Data for Name: e_fields; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY e_fields (e_field_id, et_field_id, org_id, table_code, table_id, e_field_value) FROM stdin;
\.


--
-- Name: e_fields_e_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('e_fields_e_field_id_seq', 1, false);


--
-- Data for Name: employees; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY employees (entity_id, org_id, full_name, user_name, employee_email, employee_phone, password, employee_number, pin, date_hired, id_number, verifier_phone, verifier_link, created) FROM stdin;
3	0	xx	ssdsds	koryrh@gmail.com	\N	dddfdfd	\N	\N	\N	\N	\N	\N	2018-02-11 00:20:39.693294
2	0	xx	xzx	sdsd	dsdd	sdsds	\N	dsd	2018-02-07	\N	\N	\N	2018-02-11 00:15:04.546473
5	0	koryr	koryr	koryrh@wgmail.com	\N	koryr	\N	\N	\N	\N	\N	\N	2018-02-11 14:45:48.254405
6	0	koryr	koryrs	koryrh@gmail.comd	\N	dddfdfd	\N	\N	\N	\N	\N	\N	2018-02-11 15:54:16.131917
\.


--
-- Data for Name: entity_fields; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY entity_fields (entity_field_id, org_id, use_type, is_active, entity_field_name, entity_field_source) FROM stdin;
\.


--
-- Name: entity_fields_entity_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('entity_fields_entity_field_id_seq', 1, false);


--
-- Data for Name: entity_subscriptions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY entity_subscriptions (entity_subscription_id, entity_type_id, entity_id, subscription_level_id, org_id, details) FROM stdin;
1	0	0	0	0	\N
2	0	1	0	0	\N
3	4	2	0	0	\N
4	4	3	0	0	\N
6	4	5	0	0	\N
7	4	6	0	0	\N
8	1	1	0	\N	\N
\.


--
-- Name: entity_subscriptions_entity_subscription_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('entity_subscriptions_entity_subscription_id_seq', 8, true);


--
-- Data for Name: entity_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY entity_types (entity_type_id, use_key_id, org_id, entity_type_name, entity_role, start_view, group_email, description, details) FROM stdin;
0	0	0	Users	user	\N	\N	\N	\N
1	1	0	Staff	staff	\N	\N	\N	\N
2	2	0	Client	client	\N	\N	\N	\N
3	3	0	Supplier	supplier	\N	\N	\N	\N
4	4	0	Applicant	applicant	10:0	\N	\N	\N
5	5	0	Subscription	subscription	\N	\N	\N	\N
\.


--
-- Name: entity_types_entity_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('entity_types_entity_type_id_seq', 5, true);


--
-- Data for Name: entity_values; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY entity_values (entity_value_id, entity_id, entity_field_id, org_id, entity_value) FROM stdin;
\.


--
-- Name: entity_values_entity_value_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('entity_values_entity_value_id_seq', 1, false);


--
-- Data for Name: entitys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY entitys (entity_id, entity_type_id, use_key_id, org_id, entity_name, user_name, primary_email, primary_telephone, super_user, entity_leader, no_org, function_role, date_enroled, is_active, entity_password, first_password, new_password, start_url, is_picked, details) FROM stdin;
0	0	0	0	root	root	root@localhost	\N	t	t	f	\N	2018-01-09 13:01:48.530815	t	b6f0038dfd42f8aa6ca25354cd2e3660	baraza	\N	\N	f	\N
1	0	0	0	repository	repository	repository@localhost	\N	f	t	f	\N	2018-01-09 13:01:48.530815	t	b6f0038dfd42f8aa6ca25354cd2e3660	baraza	\N	\N	f	\N
3	4	4	0	xx	ssdsds	koryrh@gmail.com	\N	f	f	f	applicant	2018-02-11 00:20:39.693294	t	4c9d032da23941ab41f217590442fac5	dddfdfd	\N	\N	f	\N
2	4	4	0	xx	xzx	sdsd	\N	f	f	f	applicant	2018-02-11 00:15:04.546473	t	51a8dbe3db8c7a39e3306f569c45ab75	453T334XY	\N	\N	f	\N
5	4	4	0	koryr	koryr	koryrh@wgmail.com	\N	f	f	f	applicant	2018-02-11 14:45:48.254405	t	41a4aa228952d95e2ffb9a02c2c12c3b	koryr	\N	\N	f	\N
6	4	4	0	koryr	koryrs	koryrh@gmail.comd	\N	f	f	f	applicant	2018-02-11 15:54:16.131917	t	4c9d032da23941ab41f217590442fac5	dddfdfd	\N	\N	f	\N
\.


--
-- Name: entitys_entity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('entitys_entity_id_seq', 6, true);


--
-- Data for Name: entry_forms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY entry_forms (entry_form_id, org_id, entity_id, form_id, entered_by_id, application_date, completion_date, approve_status, workflow_table_id, action_date, narrative, answer, sub_answer, details) FROM stdin;
\.


--
-- Name: entry_forms_entry_form_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('entry_forms_entry_form_id_seq', 1, false);


--
-- Data for Name: et_fields; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY et_fields (et_field_id, org_id, et_field_name, table_name, table_code, table_link) FROM stdin;
\.


--
-- Name: et_fields_et_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('et_fields_et_field_id_seq', 1, false);


--
-- Data for Name: fields; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) FROM stdin;
\.


--
-- Name: fields_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('fields_field_id_seq', 1, false);


--
-- Data for Name: forms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY forms (form_id, org_id, form_name, form_number, table_name, version, completed, is_active, use_key, form_header, form_footer, default_values, details) FROM stdin;
\.


--
-- Name: forms_form_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('forms_form_id_seq', 1, false);


--
-- Data for Name: orgs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY orgs (org_id, currency_id, default_country_id, parent_org_id, org_name, org_full_name, org_sufix, is_default, is_active, logo, pin, pcc, system_key, system_identifier, mac_address, public_key, license, details) FROM stdin;
0	1	\N	\N	default	\N	dc	t	t	logo.png	\N	\N	\N	\N	\N	\N	\N	\N
\.


--
-- Name: orgs_org_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('orgs_org_id_seq', 1, false);


--
-- Name: picture_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('picture_id_seq', 1, false);


--
-- Data for Name: reporting; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY reporting (reporting_id, entity_id, report_to_id, org_id, date_from, date_to, reporting_level, primary_report, is_active, ps_reporting, details) FROM stdin;
\.


--
-- Name: reporting_reporting_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('reporting_reporting_id_seq', 1, false);


--
-- Data for Name: sub_fields; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) FROM stdin;
\.


--
-- Name: sub_fields_sub_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sub_fields_sub_field_id_seq', 1, false);


--
-- Data for Name: subscription_levels; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY subscription_levels (subscription_level_id, org_id, subscription_level_name, details) FROM stdin;
0	0	Basic	\N
1	0	Consumer	\N
2	0	Manager	\N
\.


--
-- Name: subscription_levels_subscription_level_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('subscription_levels_subscription_level_id_seq', 3, true);


--
-- Data for Name: sys_audit_details; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY sys_audit_details (sys_audit_trail_id, old_value) FROM stdin;
\.


--
-- Data for Name: sys_audit_trail; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY sys_audit_trail (sys_audit_trail_id, user_id, user_ip, change_date, table_name, record_id, change_type, narrative) FROM stdin;
1	0	0:0:0:0:0:0:0:1	2018-02-11 00:15:04.566568	employees	2	INSERT	\N
2	0	0:0:0:0:0:0:0:1	2018-02-11 00:20:39.699595	employees	3	INSERT	\N
3	0	0:0:0:0:0:0:0:1	2018-02-11 14:05:07.031777	employees	2	EDIT	\N
4	0	0:0:0:0:0:0:0:1	2018-02-11 14:45:48.263496	employees	5	INSERT	\N
5	0	0:0:0:0:0:0:0:1	2018-02-11 15:54:16.147094	employees	6	INSERT	\N
6	0	0:0:0:0:0:0:0:1	2018-02-11 16:14:09.131546	entity_subscriptions	8	INSERT	\N
\.


--
-- Name: sys_audit_trail_sys_audit_trail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_audit_trail_sys_audit_trail_id_seq', 6, true);


--
-- Data for Name: sys_continents; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY sys_continents (sys_continent_id, sys_continent_name) FROM stdin;
AF	Africa
AS	Asia
EU	Europe
NA	North America
SA	South America
OC	Oceania
AN	Antarctica
\.


--
-- Data for Name: sys_countrys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) FROM stdin;
AF	AS	AFG	004	\N	Afghanistan	\N	\N	\N	\N
AX	EU	ALA	248	\N	Aland Islands	\N	\N	\N	\N
AL	EU	ALB	008	\N	Albania	\N	\N	\N	\N
DZ	AF	DZA	012	\N	Algeria	\N	\N	\N	\N
AS	OC	ASM	016	\N	American Samoa	\N	\N	\N	\N
AD	EU	AND	020	\N	Andorra	\N	\N	\N	\N
AO	AF	AGO	024	\N	Angola	\N	\N	\N	\N
AI	NA	AIA	660	\N	Anguilla	\N	\N	\N	\N
AQ	AN	ATA	010	\N	Antarctica	\N	\N	\N	\N
AG	NA	ATG	028	\N	Antigua and Barbuda	\N	\N	\N	\N
AR	SA	ARG	032	\N	Argentina	\N	\N	\N	\N
AM	AS	ARM	051	\N	Armenia	\N	\N	\N	\N
AW	NA	ABW	533	\N	Aruba	\N	\N	\N	\N
AU	OC	AUS	036	\N	Australia	\N	\N	\N	\N
AT	EU	AUT	040	\N	Austria	\N	\N	\N	\N
AZ	AS	AZE	031	\N	Azerbaijan	\N	\N	\N	\N
BS	NA	BHS	044	\N	Bahamas	\N	\N	\N	\N
BH	AS	BHR	048	\N	Bahrain	\N	\N	\N	\N
BD	AS	BGD	050	\N	Bangladesh	\N	\N	\N	\N
BB	NA	BRB	052	\N	Barbados	\N	\N	\N	\N
BY	EU	BLR	112	\N	Belarus	\N	\N	\N	\N
BE	EU	BEL	056	\N	Belgium	\N	\N	\N	\N
BZ	NA	BLZ	084	\N	Belize	\N	\N	\N	\N
BJ	AF	BEN	204	\N	Benin	\N	\N	\N	\N
BM	NA	BMU	060	\N	Bermuda	\N	\N	\N	\N
BT	AS	BTN	064	\N	Bhutan	\N	\N	\N	\N
BO	SA	BOL	068	\N	Bolivia	\N	\N	\N	\N
BA	EU	BIH	070	\N	Bosnia and Herzegovina	\N	\N	\N	\N
BW	AF	BWA	072	\N	Botswana	\N	\N	\N	\N
BV	AN	BVT	074	\N	Bouvet Island	\N	\N	\N	\N
BR	SA	BRA	076	\N	Brazil	\N	\N	\N	\N
IO	AS	IOT	086	\N	British Indian Ocean Territory	\N	\N	\N	\N
VG	NA	VGB	092	\N	British Virgin Islands	\N	\N	\N	\N
BN	AS	BRN	096	\N	Brunei Darussalam	\N	\N	\N	\N
BG	EU	BGR	100	\N	Bulgaria	\N	\N	\N	\N
BF	AF	BFA	854	\N	Burkina Faso	\N	\N	\N	\N
BI	AF	BDI	108	\N	Burundi	\N	\N	\N	\N
KH	AS	KHM	116	\N	Cambodia	\N	\N	\N	\N
CM	AF	CMR	120	\N	Cameroon	\N	\N	\N	\N
CA	NA	CAN	124	\N	Canada	\N	\N	\N	\N
CV	AF	CPV	132	\N	Cape Verde	\N	\N	\N	\N
KY	NA	CYM	136	\N	Cayman Islands	\N	\N	\N	\N
CF	AF	CAF	140	\N	Central African Republic	\N	\N	\N	\N
TD	AF	TCD	148	\N	Chad	\N	\N	\N	\N
CL	SA	CHL	152	\N	Chile	\N	\N	\N	\N
CN	AS	CHN	156	\N	China	\N	\N	\N	\N
CX	AS	CXR	162	\N	Christmas Island	\N	\N	\N	\N
CC	AS	CCK	166	\N	Cocos Keeling Islands	\N	\N	\N	\N
CO	SA	COL	170	\N	Colombia	\N	\N	\N	\N
KM	AF	COM	174	\N	Comoros	\N	\N	\N	\N
CD	AF	COD	180	\N	Democratic Republic of Congo	\N	\N	\N	\N
CG	AF	COG	178	\N	Republic of Congo	\N	\N	\N	\N
CK	OC	COK	184	\N	Cook Islands	\N	\N	\N	\N
CR	NA	CRI	188	\N	Costa Rica	\N	\N	\N	\N
CI	AF	CIV	384	\N	Cote d Ivoire	\N	\N	\N	\N
HR	EU	HRV	191	\N	Croatia	\N	\N	\N	\N
CU	NA	CUB	192	\N	Cuba	\N	\N	\N	\N
CY	AS	CYP	196	\N	Cyprus	\N	\N	\N	\N
CZ	EU	CZE	203	\N	Czech Republic	\N	\N	\N	\N
DK	EU	DNK	208	\N	Denmark	\N	\N	\N	\N
DJ	AF	DJI	262	\N	Djibouti	\N	\N	\N	\N
DM	NA	DMA	212	\N	Dominica	\N	\N	\N	\N
DO	NA	DOM	214	\N	Dominican Republic	\N	\N	\N	\N
EC	SA	ECU	218	\N	Ecuador	\N	\N	\N	\N
EG	AF	EGY	818	\N	Egypt	\N	\N	\N	\N
SV	NA	SLV	222	\N	El Salvador	\N	\N	\N	\N
GQ	AF	GNQ	226	\N	Equatorial Guinea	\N	\N	\N	\N
ER	AF	ERI	232	\N	Eritrea	\N	\N	\N	\N
EE	EU	EST	233	\N	Estonia	\N	\N	\N	\N
ET	AF	ETH	231	\N	Ethiopia	\N	\N	\N	\N
FO	EU	FRO	234	\N	Faroe Islands	\N	\N	\N	\N
FK	SA	FLK	238	\N	Falkland Islands	\N	\N	\N	\N
FJ	OC	FJI	242	\N	Fiji	\N	\N	\N	\N
FI	EU	FIN	246	\N	Finland	\N	\N	\N	\N
FR	EU	FRA	250	\N	France	\N	\N	\N	\N
GF	SA	GUF	254	\N	French Guiana	\N	\N	\N	\N
PF	OC	PYF	258	\N	French Polynesia	\N	\N	\N	\N
TF	AN	ATF	260	\N	French Southern Territories	\N	\N	\N	\N
GA	AF	GAB	266	\N	Gabon	\N	\N	\N	\N
GM	AF	GMB	270	\N	Gambia	\N	\N	\N	\N
GE	AS	GEO	268	\N	Georgia	\N	\N	\N	\N
DE	EU	DEU	276	\N	Germany	\N	\N	\N	\N
GH	AF	GHA	288	\N	Ghana	\N	\N	\N	\N
GI	EU	GIB	292	\N	Gibraltar	\N	\N	\N	\N
GR	EU	GRC	300	\N	Greece	\N	\N	\N	\N
GL	NA	GRL	304	\N	Greenland	\N	\N	\N	\N
GD	NA	GRD	308	\N	Grenada	\N	\N	\N	\N
GP	NA	GLP	312	\N	Guadeloupe	\N	\N	\N	\N
GU	OC	GUM	316	\N	Guam	\N	\N	\N	\N
GT	NA	GTM	320	\N	Guatemala	\N	\N	\N	\N
GG	EU	GGY	831	\N	Guernsey	\N	\N	\N	\N
GN	AF	GIN	324	\N	Guinea	\N	\N	\N	\N
GW	AF	GNB	624	\N	Guinea-Bissau	\N	\N	\N	\N
GY	SA	GUY	328	\N	Guyana	\N	\N	\N	\N
HT	NA	HTI	332	\N	Haiti	\N	\N	\N	\N
HM	AN	HMD	334	\N	Heard Island and McDonald Islands	\N	\N	\N	\N
VA	EU	VAT	336	\N	Vatican City State	\N	\N	\N	\N
HN	NA	HND	340	\N	Honduras	\N	\N	\N	\N
HK	AS	HKG	344	\N	Hong Kong	\N	\N	\N	\N
HU	EU	HUN	348	\N	Hungary	\N	\N	\N	\N
IS	EU	ISL	352	\N	Iceland	\N	\N	\N	\N
IN	AS	IND	356	\N	India	\N	\N	\N	\N
ID	AS	IDN	360	\N	Indonesia	\N	\N	\N	\N
IR	AS	IRN	364	\N	Iran	\N	\N	\N	\N
IQ	AS	IRQ	368	\N	Iraq	\N	\N	\N	\N
IE	EU	IRL	372	\N	Ireland	\N	\N	\N	\N
IM	EU	IMN	833	\N	Isle of Man	\N	\N	\N	\N
IL	AS	ISR	376	\N	Israel	\N	\N	\N	\N
IT	EU	ITA	380	\N	Italy	\N	\N	\N	\N
JM	NA	JAM	388	\N	Jamaica	\N	\N	\N	\N
JP	AS	JPN	392	\N	Japan	\N	\N	\N	\N
JE	EU	JEY	832	\N	Bailiwick of Jersey	\N	\N	\N	\N
JO	AS	JOR	400	\N	Jordan	\N	\N	\N	\N
KZ	AS	KAZ	398	\N	Kazakhstan	\N	\N	\N	\N
KE	AF	KEN	404	\N	Kenya	\N	\N	\N	\N
KI	OC	KIR	296	\N	Kiribati	\N	\N	\N	\N
KP	AS	PRK	408	\N	North Korea	\N	\N	\N	\N
KR	AS	KOR	410	\N	South Korea	\N	\N	\N	\N
KW	AS	KWT	414	\N	Kuwait	\N	\N	\N	\N
KG	AS	KGZ	417	\N	Kyrgyz Republic	\N	\N	\N	\N
LA	AS	LAO	418	\N	Lao Peoples Democratic Republic	\N	\N	\N	\N
LV	EU	LVA	428	\N	Latvia	\N	\N	\N	\N
LB	AS	LBN	422	\N	Lebanon	\N	\N	\N	\N
LS	AF	LSO	426	\N	Lesotho	\N	\N	\N	\N
LR	AF	LBR	430	\N	Liberia	\N	\N	\N	\N
LY	AF	LBY	434	\N	Libyan Arab Jamahiriya	\N	\N	\N	\N
LI	EU	LIE	438	\N	Liechtenstein	\N	\N	\N	\N
LT	EU	LTU	440	\N	Lithuania	\N	\N	\N	\N
LU	EU	LUX	442	\N	Luxembourg	\N	\N	\N	\N
MO	AS	MAC	446	\N	Macao	\N	\N	\N	\N
MK	EU	MKD	807	\N	Macedonia	\N	\N	\N	\N
MG	AF	MDG	450	\N	Madagascar	\N	\N	\N	\N
MW	AF	MWI	454	\N	Malawi	\N	\N	\N	\N
MY	AS	MYS	458	\N	Malaysia	\N	\N	\N	\N
MV	AS	MDV	462	\N	Maldives	\N	\N	\N	\N
ML	AF	MLI	466	\N	Mali	\N	\N	\N	\N
MT	EU	MLT	470	\N	Malta	\N	\N	\N	\N
MH	OC	MHL	584	\N	Marshall Islands	\N	\N	\N	\N
MQ	NA	MTQ	474	\N	Martinique	\N	\N	\N	\N
MR	AF	MRT	478	\N	Mauritania	\N	\N	\N	\N
MU	AF	MUS	480	\N	Mauritius	\N	\N	\N	\N
YT	AF	MYT	175	\N	Mayotte	\N	\N	\N	\N
MX	NA	MEX	484	\N	Mexico	\N	\N	\N	\N
FM	OC	FSM	583	\N	Micronesia	\N	\N	\N	\N
MD	EU	MDA	498	\N	Moldova	\N	\N	\N	\N
MC	EU	MCO	492	\N	Monaco	\N	\N	\N	\N
MN	AS	MNG	496	\N	Mongolia	\N	\N	\N	\N
ME	EU	MNE	499	\N	Montenegro	\N	\N	\N	\N
MS	NA	MSR	500	\N	Montserrat	\N	\N	\N	\N
MA	AF	MAR	504	\N	Morocco	\N	\N	\N	\N
MZ	AF	MOZ	508	\N	Mozambique	\N	\N	\N	\N
MM	AS	MMR	104	\N	Myanmar	\N	\N	\N	\N
NA	AF	NAM	516	\N	Namibia	\N	\N	\N	\N
NR	OC	NRU	520	\N	Nauru	\N	\N	\N	\N
NP	AS	NPL	524	\N	Nepal	\N	\N	\N	\N
AN	NA	ANT	530	\N	Netherlands Antilles	\N	\N	\N	\N
NL	EU	NLD	528	\N	Netherlands	\N	\N	\N	\N
NC	OC	NCL	540	\N	New Caledonia	\N	\N	\N	\N
NZ	OC	NZL	554	\N	New Zealand	\N	\N	\N	\N
NI	NA	NIC	558	\N	Nicaragua	\N	\N	\N	\N
NE	AF	NER	562	\N	Niger	\N	\N	\N	\N
NG	AF	NGA	566	\N	Nigeria	\N	\N	\N	\N
NU	OC	NIU	570	\N	Niue	\N	\N	\N	\N
NF	OC	NFK	574	\N	Norfolk Island	\N	\N	\N	\N
MP	OC	MNP	580	\N	Northern Mariana Islands	\N	\N	\N	\N
NO	EU	NOR	578	\N	Norway	\N	\N	\N	\N
OM	AS	OMN	512	\N	Oman	\N	\N	\N	\N
PK	AS	PAK	586	\N	Pakistan	\N	\N	\N	\N
PW	OC	PLW	585	\N	Palau	\N	\N	\N	\N
PS	AS	PSE	275	\N	Palestinian Territory	\N	\N	\N	\N
PA	NA	PAN	591	\N	Panama	\N	\N	\N	\N
PG	OC	PNG	598	\N	Papua New Guinea	\N	\N	\N	\N
PY	SA	PRY	600	\N	Paraguay	\N	\N	\N	\N
PE	SA	PER	604	\N	Peru	\N	\N	\N	\N
PH	AS	PHL	608	\N	Philippines	\N	\N	\N	\N
PN	OC	PCN	612	\N	Pitcairn Islands	\N	\N	\N	\N
PL	EU	POL	616	\N	Poland	\N	\N	\N	\N
PT	EU	PRT	620	\N	Portugal	\N	\N	\N	\N
PR	NA	PRI	630	\N	Puerto Rico	\N	\N	\N	\N
QA	AS	QAT	634	\N	Qatar	\N	\N	\N	\N
RE	AF	REU	638	\N	Reunion	\N	\N	\N	\N
RO	EU	ROU	642	\N	Romania	\N	\N	\N	\N
RU	EU	RUS	643	\N	Russian Federation	\N	\N	\N	\N
RW	AF	RWA	646	\N	Rwanda	\N	\N	\N	\N
BL	NA	BLM	652	\N	Saint Barthelemy	\N	\N	\N	\N
SH	AF	SHN	654	\N	Saint Helena	\N	\N	\N	\N
KN	NA	KNA	659	\N	Saint Kitts and Nevis	\N	\N	\N	\N
LC	NA	LCA	662	\N	Saint Lucia	\N	\N	\N	\N
MF	NA	MAF	663	\N	Saint Martin	\N	\N	\N	\N
PM	NA	SPM	666	\N	Saint Pierre and Miquelon	\N	\N	\N	\N
VC	NA	VCT	670	\N	Saint Vincent and the Grenadines	\N	\N	\N	\N
WS	OC	WSM	882	\N	Samoa	\N	\N	\N	\N
SM	EU	SMR	674	\N	San Marino	\N	\N	\N	\N
ST	AF	STP	678	\N	Sao Tome and Principe	\N	\N	\N	\N
SA	AS	SAU	682	\N	Saudi Arabia	\N	\N	\N	\N
SN	AF	SEN	686	\N	Senegal	\N	\N	\N	\N
RS	EU	SRB	688	\N	Serbia	\N	\N	\N	\N
SC	AF	SYC	690	\N	Seychelles	\N	\N	\N	\N
SL	AF	SLE	694	\N	Sierra Leone	\N	\N	\N	\N
SG	AS	SGP	702	\N	Singapore	\N	\N	\N	\N
SK	EU	SVK	703	\N	Slovakia	\N	\N	\N	\N
SI	EU	SVN	705	\N	Slovenia	\N	\N	\N	\N
SB	OC	SLB	090	\N	Solomon Islands	\N	\N	\N	\N
SO	AF	SOM	706	\N	Somalia	\N	\N	\N	\N
ZA	AF	ZAF	710	\N	South Africa	\N	\N	\N	\N
GS	AN	SGS	239	\N	South Georgia and the South Sandwich Islands	\N	\N	\N	\N
ES	EU	ESP	724	\N	Spain	\N	\N	\N	\N
LK	AS	LKA	144	\N	Sri Lanka	\N	\N	\N	\N
SD	AF	SDN	736	\N	Sudan	\N	\N	\N	\N
SS	AF	SSN	737	\N	South Sudan	\N	\N	\N	\N
SR	SA	SUR	740	\N	Suriname	\N	\N	\N	\N
SJ	EU	SJM	744	\N	Svalbard & Jan Mayen Islands	\N	\N	\N	\N
SZ	AF	SWZ	748	\N	Swaziland	\N	\N	\N	\N
SE	EU	SWE	752	\N	Sweden	\N	\N	\N	\N
CH	EU	CHE	756	\N	Switzerland	\N	\N	\N	\N
SY	AS	SYR	760	\N	Syrian Arab Republic	\N	\N	\N	\N
TW	AS	TWN	158	\N	Taiwan	\N	\N	\N	\N
TJ	AS	TJK	762	\N	Tajikistan	\N	\N	\N	\N
TZ	AF	TZA	834	\N	Tanzania	\N	\N	\N	\N
TH	AS	THA	764	\N	Thailand	\N	\N	\N	\N
TL	AS	TLS	626	\N	Timor-Leste	\N	\N	\N	\N
TG	AF	TGO	768	\N	Togo	\N	\N	\N	\N
TK	OC	TKL	772	\N	Tokelau	\N	\N	\N	\N
TO	OC	TON	776	\N	Tonga	\N	\N	\N	\N
TT	NA	TTO	780	\N	Trinidad and Tobago	\N	\N	\N	\N
TN	AF	TUN	788	\N	Tunisia	\N	\N	\N	\N
TR	AS	TUR	792	\N	Turkey	\N	\N	\N	\N
TM	AS	TKM	795	\N	Turkmenistan	\N	\N	\N	\N
TC	NA	TCA	796	\N	Turks and Caicos Islands	\N	\N	\N	\N
TV	OC	TUV	798	\N	Tuvalu	\N	\N	\N	\N
UG	AF	UGA	800	\N	Uganda	\N	\N	\N	\N
UA	EU	UKR	804	\N	Ukraine	\N	\N	\N	\N
AE	AS	ARE	784	\N	United Arab Emirates	\N	\N	\N	\N
GB	EU	GBR	826	\N	United Kingdom of Great Britain & Northern Ireland	\N	\N	\N	\N
US	NA	USA	840	\N	United States of America	\N	\N	\N	\N
UM	OC	UMI	581	\N	United States Minor Outlying Islands	\N	\N	\N	\N
VI	NA	VIR	850	\N	United States Virgin Islands	\N	\N	\N	\N
UY	SA	URY	858	\N	Uruguay	\N	\N	\N	\N
UZ	AS	UZB	860	\N	Uzbekistan	\N	\N	\N	\N
VU	OC	VUT	548	\N	Vanuatu	\N	\N	\N	\N
VE	SA	VEN	862	\N	Venezuela	\N	\N	\N	\N
VN	AS	VNM	704	\N	Vietnam	\N	\N	\N	\N
WF	OC	WLF	876	\N	Wallis and Futuna	\N	\N	\N	\N
EH	AF	ESH	732	\N	Western Sahara	\N	\N	\N	\N
YE	AS	YEM	887	\N	Yemen	\N	\N	\N	\N
ZM	AF	ZMB	894	\N	Zambia	\N	\N	\N	\N
ZW	AF	ZWE	716	\N	Zimbabwe	\N	\N	\N	\N
\.


--
-- Data for Name: sys_dashboard; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY sys_dashboard (sys_dashboard_id, entity_id, org_id, narrative, details) FROM stdin;
\.


--
-- Name: sys_dashboard_sys_dashboard_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_dashboard_sys_dashboard_id_seq', 1, false);


--
-- Data for Name: sys_emailed; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY sys_emailed (sys_emailed_id, sys_email_id, org_id, table_id, table_name, email_type, emailed, created, narrative, mail_body) FROM stdin;
1	\N	\N	2	applicant	1	f	2018-02-11 00:15:04.546473	\N	\N
2	\N	\N	3	employees	1	f	2018-02-11 00:20:39.693294	\N	\N
4	\N	\N	5	employees	1	f	2018-02-11 14:45:48.254405	\N	\N
5	\N	\N	6	employees	1	f	2018-02-11 15:54:16.131917	\N	\N
\.


--
-- Name: sys_emailed_sys_emailed_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_emailed_sys_emailed_id_seq', 5, true);


--
-- Data for Name: sys_emails; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY sys_emails (sys_email_id, org_id, use_type, sys_email_name, default_email, title, details) FROM stdin;
\.


--
-- Name: sys_emails_sys_email_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_emails_sys_email_id_seq', 1, false);


--
-- Data for Name: sys_errors; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY sys_errors (sys_error_id, sys_error, error_message) FROM stdin;
\.


--
-- Name: sys_errors_sys_error_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_errors_sys_error_id_seq', 1, false);


--
-- Data for Name: sys_files; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY sys_files (sys_file_id, org_id, table_id, table_name, file_name, file_type, file_size, narrative, details) FROM stdin;
\.


--
-- Name: sys_files_sys_file_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_files_sys_file_id_seq', 1, false);


--
-- Data for Name: sys_logins; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) FROM stdin;
1	0	2018-02-10 15:08:22.660374	127.0.0.1	\N
2	0	2018-02-10 17:52:21.360499	0:0:0:0:0:0:0:1	\N
3	0	2018-02-10 17:52:21.367535	0:0:0:0:0:0:0:1	\N
4	0	2018-02-10 17:52:22.28753	0:0:0:0:0:0:0:1	\N
5	0	2018-02-10 17:52:22.298858	0:0:0:0:0:0:0:1	\N
\.


--
-- Name: sys_logins_sys_login_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_logins_sys_login_id_seq', 5, true);


--
-- Data for Name: sys_menu_msg; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY sys_menu_msg (sys_menu_msg_id, menu_id, menu_name, xml_file, msg) FROM stdin;
\.


--
-- Name: sys_menu_msg_sys_menu_msg_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_menu_msg_sys_menu_msg_id_seq', 1, false);


--
-- Data for Name: sys_news; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY sys_news (sys_news_id, org_id, sys_news_group, sys_news_title, publish, details) FROM stdin;
\.


--
-- Name: sys_news_sys_news_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_news_sys_news_id_seq', 1, false);


--
-- Data for Name: sys_queries; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY sys_queries (sys_queries_id, org_id, sys_query_name, query_date, query_text, query_params) FROM stdin;
\.


--
-- Name: sys_queries_sys_queries_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_queries_sys_queries_id_seq', 1, false);


--
-- Data for Name: sys_reset; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY sys_reset (sys_reset_id, entity_id, org_id, request_email, request_time, login_ip, narrative) FROM stdin;
\.


--
-- Name: sys_reset_sys_reset_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_reset_sys_reset_id_seq', 1, false);


--
-- Data for Name: use_keys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY use_keys (use_key_id, use_key_name, use_function) FROM stdin;
0	Users	0
1	Staff	0
2	Client	0
3	Supplier	0
4	Applicant	0
5	Subscription	0
\.


--
-- Data for Name: workflow_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY workflow_logs (workflow_log_id, org_id, table_name, table_id, table_old_id) FROM stdin;
\.


--
-- Name: workflow_logs_workflow_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('workflow_logs_workflow_log_id_seq', 1, false);


--
-- Data for Name: workflow_phases; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY workflow_phases (workflow_phase_id, workflow_id, approval_entity_id, org_id, approval_level, return_level, escalation_days, escalation_hours, required_approvals, reporting_level, use_reporting, advice, notice, phase_narrative, advice_email, notice_email, advice_file, notice_file, details) FROM stdin;
\.


--
-- Name: workflow_phases_workflow_phase_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('workflow_phases_workflow_phase_id_seq', 1, false);


--
-- Data for Name: workflow_sql; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY workflow_sql (workflow_sql_id, workflow_phase_id, org_id, workflow_sql_name, is_condition, is_action, message, sql) FROM stdin;
\.


--
-- Name: workflow_sql_workflow_sql_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('workflow_sql_workflow_sql_id_seq', 1, false);


--
-- Name: workflow_table_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('workflow_table_id_seq', 1, false);


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY workflows (workflow_id, source_entity_id, org_id, workflow_name, table_name, table_link_field, table_link_id, approve_email, reject_email, approve_file, reject_file, link_copy, details) FROM stdin;
\.


--
-- Name: workflows_workflow_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('workflows_workflow_id_seq', 1, false);


--
-- Name: address_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY address
    ADD CONSTRAINT address_pkey PRIMARY KEY (address_id);


--
-- Name: address_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY address_types
    ADD CONSTRAINT address_types_pkey PRIMARY KEY (address_type_id);


--
-- Name: approval_checklists_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY approval_checklists
    ADD CONSTRAINT approval_checklists_pkey PRIMARY KEY (approval_checklist_id);


--
-- Name: approvals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY approvals
    ADD CONSTRAINT approvals_pkey PRIMARY KEY (approval_id);


--
-- Name: checklists_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY checklists
    ADD CONSTRAINT checklists_pkey PRIMARY KEY (checklist_id);


--
-- Name: currency_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY currency
    ADD CONSTRAINT currency_pkey PRIMARY KEY (currency_id);


--
-- Name: currency_rates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY currency_rates
    ADD CONSTRAINT currency_rates_pkey PRIMARY KEY (currency_rate_id);


--
-- Name: e_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_fields
    ADD CONSTRAINT e_fields_pkey PRIMARY KEY (e_field_id);


--
-- Name: employees_employee_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY employees
    ADD CONSTRAINT employees_employee_email_key UNIQUE (employee_email);


--
-- Name: employees_org_id_entity_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY employees
    ADD CONSTRAINT employees_org_id_entity_id_key UNIQUE (org_id, entity_id);


--
-- Name: employees_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (entity_id);


--
-- Name: employees_user_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY employees
    ADD CONSTRAINT employees_user_name_key UNIQUE (user_name);


--
-- Name: entity_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entity_fields
    ADD CONSTRAINT entity_fields_pkey PRIMARY KEY (entity_field_id);


--
-- Name: entity_subscriptions_entity_id_entity_type_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_entity_id_entity_type_id_key UNIQUE (entity_id, entity_type_id);


--
-- Name: entity_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_pkey PRIMARY KEY (entity_subscription_id);


--
-- Name: entity_types_org_id_entity_type_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entity_types
    ADD CONSTRAINT entity_types_org_id_entity_type_name_key UNIQUE (org_id, entity_type_name);


--
-- Name: entity_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entity_types
    ADD CONSTRAINT entity_types_pkey PRIMARY KEY (entity_type_id);


--
-- Name: entity_values_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entity_values
    ADD CONSTRAINT entity_values_pkey PRIMARY KEY (entity_value_id);


--
-- Name: entitys_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_pkey PRIMARY KEY (entity_id);


--
-- Name: entitys_user_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_user_name_key UNIQUE (user_name);


--
-- Name: entry_forms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entry_forms
    ADD CONSTRAINT entry_forms_pkey PRIMARY KEY (entry_form_id);


--
-- Name: et_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY et_fields
    ADD CONSTRAINT et_fields_pkey PRIMARY KEY (et_field_id);


--
-- Name: fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY fields
    ADD CONSTRAINT fields_pkey PRIMARY KEY (field_id);


--
-- Name: forms_form_name_version_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY forms
    ADD CONSTRAINT forms_form_name_version_key UNIQUE (form_name, version);


--
-- Name: forms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY forms
    ADD CONSTRAINT forms_pkey PRIMARY KEY (form_id);


--
-- Name: orgs_org_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_org_name_key UNIQUE (org_name);


--
-- Name: orgs_org_sufix_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_org_sufix_key UNIQUE (org_sufix);


--
-- Name: orgs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_pkey PRIMARY KEY (org_id);


--
-- Name: reporting_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY reporting
    ADD CONSTRAINT reporting_pkey PRIMARY KEY (reporting_id);


--
-- Name: sub_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sub_fields
    ADD CONSTRAINT sub_fields_pkey PRIMARY KEY (sub_field_id);


--
-- Name: subscription_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY subscription_levels
    ADD CONSTRAINT subscription_levels_pkey PRIMARY KEY (subscription_level_id);


--
-- Name: sys_audit_details_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_audit_details
    ADD CONSTRAINT sys_audit_details_pkey PRIMARY KEY (sys_audit_trail_id);


--
-- Name: sys_audit_trail_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_audit_trail
    ADD CONSTRAINT sys_audit_trail_pkey PRIMARY KEY (sys_audit_trail_id);


--
-- Name: sys_continents_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_continents
    ADD CONSTRAINT sys_continents_pkey PRIMARY KEY (sys_continent_id);


--
-- Name: sys_continents_sys_continent_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_continents
    ADD CONSTRAINT sys_continents_sys_continent_name_key UNIQUE (sys_continent_name);


--
-- Name: sys_countrys_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_countrys
    ADD CONSTRAINT sys_countrys_pkey PRIMARY KEY (sys_country_id);


--
-- Name: sys_countrys_sys_country_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_countrys
    ADD CONSTRAINT sys_countrys_sys_country_name_key UNIQUE (sys_country_name);


--
-- Name: sys_dashboard_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_dashboard
    ADD CONSTRAINT sys_dashboard_pkey PRIMARY KEY (sys_dashboard_id);


--
-- Name: sys_emailed_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_emailed
    ADD CONSTRAINT sys_emailed_pkey PRIMARY KEY (sys_emailed_id);


--
-- Name: sys_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_emails
    ADD CONSTRAINT sys_emails_pkey PRIMARY KEY (sys_email_id);


--
-- Name: sys_errors_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_errors
    ADD CONSTRAINT sys_errors_pkey PRIMARY KEY (sys_error_id);


--
-- Name: sys_files_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_files
    ADD CONSTRAINT sys_files_pkey PRIMARY KEY (sys_file_id);


--
-- Name: sys_logins_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_logins
    ADD CONSTRAINT sys_logins_pkey PRIMARY KEY (sys_login_id);


--
-- Name: sys_menu_msg_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_menu_msg
    ADD CONSTRAINT sys_menu_msg_pkey PRIMARY KEY (sys_menu_msg_id);


--
-- Name: sys_news_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_news
    ADD CONSTRAINT sys_news_pkey PRIMARY KEY (sys_news_id);


--
-- Name: sys_queries_org_id_sys_query_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_queries
    ADD CONSTRAINT sys_queries_org_id_sys_query_name_key UNIQUE (org_id, sys_query_name);


--
-- Name: sys_queries_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_queries
    ADD CONSTRAINT sys_queries_pkey PRIMARY KEY (sys_queries_id);


--
-- Name: sys_reset_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_reset
    ADD CONSTRAINT sys_reset_pkey PRIMARY KEY (sys_reset_id);


--
-- Name: use_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY use_keys
    ADD CONSTRAINT use_keys_pkey PRIMARY KEY (use_key_id);


--
-- Name: workflow_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY workflow_logs
    ADD CONSTRAINT workflow_logs_pkey PRIMARY KEY (workflow_log_id);


--
-- Name: workflow_phases_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY workflow_phases
    ADD CONSTRAINT workflow_phases_pkey PRIMARY KEY (workflow_phase_id);


--
-- Name: workflow_sql_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY workflow_sql
    ADD CONSTRAINT workflow_sql_pkey PRIMARY KEY (workflow_sql_id);


--
-- Name: workflows_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY workflows
    ADD CONSTRAINT workflows_pkey PRIMARY KEY (workflow_id);


--
-- Name: address_address_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX address_address_type_id ON address USING btree (address_type_id);


--
-- Name: address_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX address_org_id ON address USING btree (org_id);


--
-- Name: address_sys_country_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX address_sys_country_id ON address USING btree (sys_country_id);


--
-- Name: address_table_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX address_table_id ON address USING btree (table_id);


--
-- Name: address_table_name; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX address_table_name ON address USING btree (table_name);


--
-- Name: address_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX address_types_org_id ON address_types USING btree (org_id);


--
-- Name: approval_checklists_approval_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approval_checklists_approval_id ON approval_checklists USING btree (approval_id);


--
-- Name: approval_checklists_checklist_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approval_checklists_checklist_id ON approval_checklists USING btree (checklist_id);


--
-- Name: approval_checklists_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approval_checklists_org_id ON approval_checklists USING btree (org_id);


--
-- Name: approvals_app_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvals_app_entity_id ON approvals USING btree (app_entity_id);


--
-- Name: approvals_approve_status; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvals_approve_status ON approvals USING btree (approve_status);


--
-- Name: approvals_forward_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvals_forward_id ON approvals USING btree (forward_id);


--
-- Name: approvals_org_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvals_org_entity_id ON approvals USING btree (org_entity_id);


--
-- Name: approvals_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvals_org_id ON approvals USING btree (org_id);


--
-- Name: approvals_table_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvals_table_id ON approvals USING btree (table_id);


--
-- Name: approvals_workflow_phase_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvals_workflow_phase_id ON approvals USING btree (workflow_phase_id);


--
-- Name: checklists_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX checklists_org_id ON checklists USING btree (org_id);


--
-- Name: checklists_workflow_phase_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX checklists_workflow_phase_id ON checklists USING btree (workflow_phase_id);


--
-- Name: currency_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX currency_org_id ON currency USING btree (org_id);


--
-- Name: currency_rates_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX currency_rates_currency_id ON currency_rates USING btree (currency_id);


--
-- Name: currency_rates_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX currency_rates_org_id ON currency_rates USING btree (org_id);


--
-- Name: e_fields_et_field_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX e_fields_et_field_id ON e_fields USING btree (et_field_id);


--
-- Name: e_fields_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX e_fields_org_id ON e_fields USING btree (org_id);


--
-- Name: e_fields_table_code; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX e_fields_table_code ON e_fields USING btree (table_code);


--
-- Name: e_fields_table_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX e_fields_table_id ON e_fields USING btree (table_id);


--
-- Name: employees_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX employees_org_id ON employees USING btree (org_id);


--
-- Name: entity_fields_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_fields_org_id ON entity_fields USING btree (org_id);


--
-- Name: entity_subscriptions_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_subscriptions_entity_id ON entity_subscriptions USING btree (entity_id);


--
-- Name: entity_subscriptions_entity_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_subscriptions_entity_type_id ON entity_subscriptions USING btree (entity_type_id);


--
-- Name: entity_subscriptions_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_subscriptions_org_id ON entity_subscriptions USING btree (org_id);


--
-- Name: entity_subscriptions_subscription_level_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_subscriptions_subscription_level_id ON entity_subscriptions USING btree (subscription_level_id);


--
-- Name: entity_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_types_org_id ON entity_types USING btree (org_id);


--
-- Name: entity_types_use_key_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_types_use_key_id ON entity_types USING btree (use_key_id);


--
-- Name: entity_values_entity_field_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_values_entity_field_id ON entity_values USING btree (entity_field_id);


--
-- Name: entity_values_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_values_entity_id ON entity_values USING btree (entity_id);


--
-- Name: entity_values_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_values_org_id ON entity_values USING btree (org_id);


--
-- Name: entitys_entity_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entitys_entity_type_id ON entitys USING btree (entity_type_id);


--
-- Name: entitys_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entitys_org_id ON entitys USING btree (org_id);


--
-- Name: entitys_use_key_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entitys_use_key_id ON entitys USING btree (use_key_id);


--
-- Name: entitys_user_name; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entitys_user_name ON entitys USING btree (user_name);


--
-- Name: entry_forms_entered_by_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entry_forms_entered_by_id ON entry_forms USING btree (entered_by_id);


--
-- Name: entry_forms_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entry_forms_entity_id ON entry_forms USING btree (entity_id);


--
-- Name: entry_forms_form_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entry_forms_form_id ON entry_forms USING btree (form_id);


--
-- Name: entry_forms_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entry_forms_org_id ON entry_forms USING btree (org_id);


--
-- Name: et_fields_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX et_fields_org_id ON et_fields USING btree (org_id);


--
-- Name: et_fields_table_code; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX et_fields_table_code ON et_fields USING btree (table_code);


--
-- Name: et_fields_table_link; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX et_fields_table_link ON et_fields USING btree (table_link);


--
-- Name: fields_form_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX fields_form_id ON fields USING btree (form_id);


--
-- Name: fields_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX fields_org_id ON fields USING btree (org_id);


--
-- Name: forms_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX forms_org_id ON forms USING btree (org_id);


--
-- Name: orgs_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX orgs_currency_id ON orgs USING btree (currency_id);


--
-- Name: orgs_default_country_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX orgs_default_country_id ON orgs USING btree (default_country_id);


--
-- Name: orgs_parent_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX orgs_parent_org_id ON orgs USING btree (parent_org_id);


--
-- Name: reporting_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX reporting_entity_id ON reporting USING btree (entity_id);


--
-- Name: reporting_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX reporting_org_id ON reporting USING btree (org_id);


--
-- Name: reporting_report_to_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX reporting_report_to_id ON reporting USING btree (report_to_id);


--
-- Name: sub_fields_field_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sub_fields_field_id ON sub_fields USING btree (field_id);


--
-- Name: sub_fields_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sub_fields_org_id ON sub_fields USING btree (org_id);


--
-- Name: subscription_levels_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX subscription_levels_org_id ON subscription_levels USING btree (org_id);


--
-- Name: sys_countrys_sys_continent_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_countrys_sys_continent_id ON sys_countrys USING btree (sys_continent_id);


--
-- Name: sys_dashboard_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_dashboard_entity_id ON sys_dashboard USING btree (entity_id);


--
-- Name: sys_dashboard_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_dashboard_org_id ON sys_dashboard USING btree (org_id);


--
-- Name: sys_emailed_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_emailed_org_id ON sys_emailed USING btree (org_id);


--
-- Name: sys_emailed_sys_email_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_emailed_sys_email_id ON sys_emailed USING btree (sys_email_id);


--
-- Name: sys_emailed_table_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_emailed_table_id ON sys_emailed USING btree (table_id);


--
-- Name: sys_emails_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_emails_org_id ON sys_emails USING btree (org_id);


--
-- Name: sys_files_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_files_org_id ON sys_files USING btree (org_id);


--
-- Name: sys_files_table_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_files_table_id ON sys_files USING btree (table_id);


--
-- Name: sys_logins_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_logins_entity_id ON sys_logins USING btree (entity_id);


--
-- Name: sys_news_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_news_org_id ON sys_news USING btree (org_id);


--
-- Name: sys_queries_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_queries_org_id ON sys_queries USING btree (org_id);


--
-- Name: sys_reset_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_reset_entity_id ON sys_reset USING btree (entity_id);


--
-- Name: sys_reset_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_reset_org_id ON sys_reset USING btree (org_id);


--
-- Name: workflow_logs_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflow_logs_org_id ON workflow_logs USING btree (org_id);


--
-- Name: workflow_phases_approval_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflow_phases_approval_entity_id ON workflow_phases USING btree (approval_entity_id);


--
-- Name: workflow_phases_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflow_phases_org_id ON workflow_phases USING btree (org_id);


--
-- Name: workflow_phases_workflow_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflow_phases_workflow_id ON workflow_phases USING btree (workflow_id);


--
-- Name: workflow_sql_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflow_sql_org_id ON workflow_sql USING btree (org_id);


--
-- Name: workflow_sql_workflow_phase_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflow_sql_workflow_phase_id ON workflow_sql USING btree (workflow_phase_id);


--
-- Name: workflows_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflows_org_id ON workflows USING btree (org_id);


--
-- Name: workflows_source_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflows_source_entity_id ON workflows USING btree (source_entity_id);


--
-- Name: ins_address; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_address BEFORE INSERT OR UPDATE ON address FOR EACH ROW EXECUTE PROCEDURE ins_address();


--
-- Name: ins_applicants; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_applicants BEFORE INSERT OR UPDATE ON employees FOR EACH ROW EXECUTE PROCEDURE ins_applicants();


--
-- Name: ins_approvals; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_approvals BEFORE INSERT ON approvals FOR EACH ROW EXECUTE PROCEDURE ins_approvals();


--
-- Name: ins_entitys; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_entitys AFTER INSERT ON entitys FOR EACH ROW EXECUTE PROCEDURE ins_entitys();


--
-- Name: ins_entry_forms; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_entry_forms BEFORE INSERT ON entry_forms FOR EACH ROW EXECUTE PROCEDURE ins_entry_forms();


--
-- Name: ins_fields; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_fields BEFORE INSERT ON fields FOR EACH ROW EXECUTE PROCEDURE ins_fields();


--
-- Name: ins_password; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_password BEFORE INSERT OR UPDATE ON entitys FOR EACH ROW EXECUTE PROCEDURE ins_password();


--
-- Name: ins_sub_fields; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_sub_fields BEFORE INSERT ON sub_fields FOR EACH ROW EXECUTE PROCEDURE ins_sub_fields();


--
-- Name: ins_sys_reset; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_sys_reset AFTER INSERT ON sys_reset FOR EACH ROW EXECUTE PROCEDURE ins_sys_reset();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON entry_forms FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_approvals; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_approvals AFTER INSERT OR UPDATE ON approvals FOR EACH ROW EXECUTE PROCEDURE upd_approvals();


--
-- Name: address_address_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address
    ADD CONSTRAINT address_address_type_id_fkey FOREIGN KEY (address_type_id) REFERENCES address_types(address_type_id);


--
-- Name: address_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address
    ADD CONSTRAINT address_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: address_sys_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address
    ADD CONSTRAINT address_sys_country_id_fkey FOREIGN KEY (sys_country_id) REFERENCES sys_countrys(sys_country_id);


--
-- Name: address_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address_types
    ADD CONSTRAINT address_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: approval_checklists_approval_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approval_checklists
    ADD CONSTRAINT approval_checklists_approval_id_fkey FOREIGN KEY (approval_id) REFERENCES approvals(approval_id);


--
-- Name: approval_checklists_checklist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approval_checklists
    ADD CONSTRAINT approval_checklists_checklist_id_fkey FOREIGN KEY (checklist_id) REFERENCES checklists(checklist_id);


--
-- Name: approval_checklists_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approval_checklists
    ADD CONSTRAINT approval_checklists_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: approvals_app_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approvals
    ADD CONSTRAINT approvals_app_entity_id_fkey FOREIGN KEY (app_entity_id) REFERENCES entitys(entity_id);


--
-- Name: approvals_org_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approvals
    ADD CONSTRAINT approvals_org_entity_id_fkey FOREIGN KEY (org_entity_id) REFERENCES entitys(entity_id);


--
-- Name: approvals_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approvals
    ADD CONSTRAINT approvals_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: approvals_workflow_phase_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approvals
    ADD CONSTRAINT approvals_workflow_phase_id_fkey FOREIGN KEY (workflow_phase_id) REFERENCES workflow_phases(workflow_phase_id);


--
-- Name: checklists_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY checklists
    ADD CONSTRAINT checklists_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: checklists_workflow_phase_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY checklists
    ADD CONSTRAINT checklists_workflow_phase_id_fkey FOREIGN KEY (workflow_phase_id) REFERENCES workflow_phases(workflow_phase_id);


--
-- Name: currency_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY currency
    ADD CONSTRAINT currency_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: currency_rates_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY currency_rates
    ADD CONSTRAINT currency_rates_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: currency_rates_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY currency_rates
    ADD CONSTRAINT currency_rates_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: e_fields_et_field_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY e_fields
    ADD CONSTRAINT e_fields_et_field_id_fkey FOREIGN KEY (et_field_id) REFERENCES et_fields(et_field_id);


--
-- Name: e_fields_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY e_fields
    ADD CONSTRAINT e_fields_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: employees_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY employees
    ADD CONSTRAINT employees_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: employees_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY employees
    ADD CONSTRAINT employees_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entity_fields_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_fields
    ADD CONSTRAINT entity_fields_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entity_subscriptions_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: entity_subscriptions_entity_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_entity_type_id_fkey FOREIGN KEY (entity_type_id) REFERENCES entity_types(entity_type_id);


--
-- Name: entity_subscriptions_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entity_subscriptions_subscription_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_subscription_level_id_fkey FOREIGN KEY (subscription_level_id) REFERENCES subscription_levels(subscription_level_id);


--
-- Name: entity_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_types
    ADD CONSTRAINT entity_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entity_types_use_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_types
    ADD CONSTRAINT entity_types_use_key_id_fkey FOREIGN KEY (use_key_id) REFERENCES use_keys(use_key_id);


--
-- Name: entity_values_entity_field_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_values
    ADD CONSTRAINT entity_values_entity_field_id_fkey FOREIGN KEY (entity_field_id) REFERENCES entity_fields(entity_field_id);


--
-- Name: entity_values_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_values
    ADD CONSTRAINT entity_values_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: entity_values_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_values
    ADD CONSTRAINT entity_values_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entitys_entity_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_entity_type_id_fkey FOREIGN KEY (entity_type_id) REFERENCES entity_types(entity_type_id);


--
-- Name: entitys_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entitys_use_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_use_key_id_fkey FOREIGN KEY (use_key_id) REFERENCES use_keys(use_key_id);


--
-- Name: entry_forms_entered_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entry_forms
    ADD CONSTRAINT entry_forms_entered_by_id_fkey FOREIGN KEY (entered_by_id) REFERENCES entitys(entity_id);


--
-- Name: entry_forms_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entry_forms
    ADD CONSTRAINT entry_forms_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: entry_forms_form_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entry_forms
    ADD CONSTRAINT entry_forms_form_id_fkey FOREIGN KEY (form_id) REFERENCES forms(form_id);


--
-- Name: entry_forms_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entry_forms
    ADD CONSTRAINT entry_forms_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: et_fields_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY et_fields
    ADD CONSTRAINT et_fields_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: fields_form_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY fields
    ADD CONSTRAINT fields_form_id_fkey FOREIGN KEY (form_id) REFERENCES forms(form_id);


--
-- Name: fields_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY fields
    ADD CONSTRAINT fields_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: forms_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY forms
    ADD CONSTRAINT forms_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: orgs_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: orgs_default_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_default_country_id_fkey FOREIGN KEY (default_country_id) REFERENCES sys_countrys(sys_country_id);


--
-- Name: orgs_parent_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_parent_org_id_fkey FOREIGN KEY (parent_org_id) REFERENCES orgs(org_id);


--
-- Name: reporting_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reporting
    ADD CONSTRAINT reporting_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: reporting_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reporting
    ADD CONSTRAINT reporting_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: reporting_report_to_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reporting
    ADD CONSTRAINT reporting_report_to_id_fkey FOREIGN KEY (report_to_id) REFERENCES entitys(entity_id);


--
-- Name: sub_fields_field_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sub_fields
    ADD CONSTRAINT sub_fields_field_id_fkey FOREIGN KEY (field_id) REFERENCES fields(field_id);


--
-- Name: sub_fields_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sub_fields
    ADD CONSTRAINT sub_fields_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: subscription_levels_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY subscription_levels
    ADD CONSTRAINT subscription_levels_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_audit_details_sys_audit_trail_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_audit_details
    ADD CONSTRAINT sys_audit_details_sys_audit_trail_id_fkey FOREIGN KEY (sys_audit_trail_id) REFERENCES sys_audit_trail(sys_audit_trail_id);


--
-- Name: sys_countrys_sys_continent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_countrys
    ADD CONSTRAINT sys_countrys_sys_continent_id_fkey FOREIGN KEY (sys_continent_id) REFERENCES sys_continents(sys_continent_id);


--
-- Name: sys_dashboard_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_dashboard
    ADD CONSTRAINT sys_dashboard_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: sys_dashboard_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_dashboard
    ADD CONSTRAINT sys_dashboard_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_emailed_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_emailed
    ADD CONSTRAINT sys_emailed_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_emailed_sys_email_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_emailed
    ADD CONSTRAINT sys_emailed_sys_email_id_fkey FOREIGN KEY (sys_email_id) REFERENCES sys_emails(sys_email_id);


--
-- Name: sys_emails_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_emails
    ADD CONSTRAINT sys_emails_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_files_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_files
    ADD CONSTRAINT sys_files_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_logins_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_logins
    ADD CONSTRAINT sys_logins_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: sys_news_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_news
    ADD CONSTRAINT sys_news_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_queries_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_queries
    ADD CONSTRAINT sys_queries_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_reset_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_reset
    ADD CONSTRAINT sys_reset_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: sys_reset_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_reset
    ADD CONSTRAINT sys_reset_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: workflow_logs_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_logs
    ADD CONSTRAINT workflow_logs_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: workflow_phases_approval_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_phases
    ADD CONSTRAINT workflow_phases_approval_entity_id_fkey FOREIGN KEY (approval_entity_id) REFERENCES entity_types(entity_type_id);


--
-- Name: workflow_phases_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_phases
    ADD CONSTRAINT workflow_phases_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: workflow_phases_workflow_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_phases
    ADD CONSTRAINT workflow_phases_workflow_id_fkey FOREIGN KEY (workflow_id) REFERENCES workflows(workflow_id);


--
-- Name: workflow_sql_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_sql
    ADD CONSTRAINT workflow_sql_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: workflow_sql_workflow_phase_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_sql
    ADD CONSTRAINT workflow_sql_workflow_phase_id_fkey FOREIGN KEY (workflow_phase_id) REFERENCES workflow_phases(workflow_phase_id);


--
-- Name: workflows_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflows
    ADD CONSTRAINT workflows_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: workflows_source_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflows
    ADD CONSTRAINT workflows_source_entity_id_fkey FOREIGN KEY (source_entity_id) REFERENCES entity_types(entity_type_id);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

