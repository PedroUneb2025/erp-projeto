CREATE TABLE dw.dim_tempo (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 created_by bigint, deleted_at timestamptz,
 data date NOT NULL UNIQUE, ano integer NOT NULL, mes integer NOT NULL CHECK(mes BETWEEN 1 AND 12), dia integer NOT NULL CHECK(dia BETWEEN 1 AND 31)
);
CREATE TABLE dw.dim_clientes (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 created_by bigint, deleted_at timestamptz,
 origem text NOT NULL, origem_id text NOT NULL, nome text NOT NULL, UNIQUE(origem,origem_id)
);
CREATE PROCEDURE dw.sp_carregar_dim_clientes(p_origem text,p_id text,p_nome text) LANGUAGE sql AS $$
 INSERT INTO dw.dim_clientes(origem,origem_id,nome) VALUES(p_origem,p_id,p_nome)
 ON CONFLICT(origem,origem_id) DO UPDATE SET nome=excluded.nome,updated_at=now(),deleted_at=NULL;
$$;
CREATE TABLE dw.dim_produtos (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 created_by bigint, deleted_at timestamptz,
 origem text NOT NULL, origem_id text NOT NULL, nome text NOT NULL, UNIQUE(origem,origem_id)
);
CREATE PROCEDURE dw.sp_carregar_dim_produtos(p_origem text,p_id text,p_nome text) LANGUAGE sql AS $$
 INSERT INTO dw.dim_produtos(origem,origem_id,nome) VALUES(p_origem,p_id,p_nome)
 ON CONFLICT(origem,origem_id) DO UPDATE SET nome=excluded.nome,updated_at=now(),deleted_at=NULL;
$$;
CREATE TABLE dw.dim_fornecedores (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 created_by bigint, deleted_at timestamptz,
 origem text NOT NULL, origem_id text NOT NULL, nome text NOT NULL, UNIQUE(origem,origem_id)
);
CREATE PROCEDURE dw.sp_carregar_dim_fornecedores(p_origem text,p_id text,p_nome text) LANGUAGE sql AS $$
 INSERT INTO dw.dim_fornecedores(origem,origem_id,nome) VALUES(p_origem,p_id,p_nome)
 ON CONFLICT(origem,origem_id) DO UPDATE SET nome=excluded.nome,updated_at=now(),deleted_at=NULL;
$$;
CREATE PROCEDURE dw.sp_carregar_dim_tempo(p_inicio date,p_fim date) LANGUAGE plpgsql AS $$
BEGIN
 IF p_fim<p_inicio OR p_fim-p_inicio>36600 THEN RAISE EXCEPTION 'Intervalo invalido'; END IF;
 INSERT INTO dw.dim_tempo(data,ano,mes,dia) SELECT d::date,extract(year FROM d),extract(month FROM d),extract(day FROM d)
 FROM generate_series(p_inicio::timestamp,p_fim::timestamp,interval '1 day') d ON CONFLICT(data) DO NOTHING;
END $$;
CREATE FUNCTION dw.fn_mes(p_data date) RETURNS date LANGUAGE sql IMMUTABLE AS $$ SELECT date_trunc('month',p_data::timestamp)::date $$;
