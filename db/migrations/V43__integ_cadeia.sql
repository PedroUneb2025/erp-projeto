CREATE TABLE integ.blocos (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 created_by bigint, deleted_at timestamptz,
 anterior text NOT NULL, hash text NOT NULL UNIQUE, dados jsonb NOT NULL
);

CREATE FUNCTION integ.fn_registrar_bloco(p_dados jsonb) RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE ant text; novo bigint;
BEGIN
 PERFORM pg_advisory_xact_lock(43001);
 SELECT hash INTO ant FROM integ.blocos ORDER BY id DESC LIMIT 1;
 ant:=coalesce(ant,repeat('0',64));
 INSERT INTO integ.blocos(anterior,hash,dados,created_by) VALUES(ant,
 encode(digest(ant||p_dados::text,'sha256'),'hex'),p_dados,nullif(current_setting('app.usuario_id',true),'')::bigint) RETURNING id INTO novo;
 RETURN novo;
END $$;
CREATE FUNCTION integ.fn_verificar_cadeia() RETURNS boolean LANGUAGE plpgsql STABLE AS $$
DECLARE ant text:=repeat('0',64); r record;
BEGIN
 FOR r IN SELECT * FROM integ.blocos ORDER BY id LOOP
 IF r.anterior<>ant OR r.hash<>encode(digest(ant||r.dados::text,'sha256'),'hex') THEN RETURN false; END IF;
 ant:=r.hash;
 END LOOP; RETURN true;
END $$;
CREATE FUNCTION integ.fn_bloquear_mutacao_bloco() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Blocos sao append-only'; END $$;
CREATE TRIGGER trg_blocos_imutaveis BEFORE UPDATE OR DELETE ON integ.blocos FOR EACH ROW EXECUTE FUNCTION integ.fn_bloquear_mutacao_bloco();
CREATE TRIGGER trg_blocos_truncate BEFORE TRUNCATE ON integ.blocos FOR EACH STATEMENT EXECUTE FUNCTION integ.fn_bloquear_mutacao_bloco();
COMMENT ON TABLE integ.blocos IS 'Cadeia de hashes local; nao e blockchain distribuida. A verificacao nao detecta truncamento do final por um DBA sem ancora externa.';
