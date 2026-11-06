CREATE TABLE integ.eventos (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 created_by bigint, deleted_at timestamptz,
 canal text NOT NULL, chave text NOT NULL, direcao text NOT NULL CHECK(direcao IN ('entrada','saida')), payload jsonb NOT NULL, estado text NOT NULL DEFAULT 'pendente' CHECK(estado IN ('pendente','concluido','falha','recebido')), tentativas integer NOT NULL DEFAULT 0 CHECK(tentativas>=0), proxima_tentativa timestamptz NOT NULL DEFAULT now(), UNIQUE(canal,chave,direcao)
);
CREATE TABLE integ.log_chamadas (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 created_by bigint, deleted_at timestamptz,
 evento_id bigint NOT NULL REFERENCES integ.eventos(id), tentativa integer NOT NULL, http_status integer, erro text, duracao_ms integer NOT NULL CHECK(duracao_ms>=0)
);

CREATE INDEX ix_eventos_proxima_tentativa ON integ.eventos(proxima_tentativa) WHERE estado='pendente' AND deleted_at IS NULL;
CREATE INDEX ix_log_chamadas_evento_id ON integ.log_chamadas(evento_id);
CREATE TRIGGER trg_eventos_auditoria BEFORE INSERT OR UPDATE OR DELETE ON integ.eventos FOR EACH ROW EXECUTE FUNCTION sys.fn_auditar();
CREATE FUNCTION integ.fn_atraso_retry(p_tentativa integer) RETURNS integer LANGUAGE sql IMMUTABLE AS $$ SELECT least(3600, (power(2,least(10,greatest(0,p_tentativa)))*5)::integer) $$;
CREATE PROCEDURE integ.sp_reprocessar_falhas(p_id bigint) LANGUAGE plpgsql AS $$
BEGIN
 UPDATE integ.eventos SET estado='pendente',tentativas=0,proxima_tentativa=now() WHERE id=p_id AND estado='falha' AND direcao='saida' AND deleted_at IS NULL;
 IF NOT FOUND THEN RAISE EXCEPTION 'Evento inexistente ou nao reprocessavel'; END IF;
END $$;
CREATE VIEW integ.vw_integracoes_com_erro AS SELECT id,canal,chave,tentativas,updated_at FROM integ.eventos WHERE estado='falha' AND deleted_at IS NULL;
CREATE VIEW integ.vw_resumo_integracoes AS SELECT canal,direcao,estado,count(*) total FROM integ.eventos WHERE deleted_at IS NULL GROUP BY 1,2,3;
