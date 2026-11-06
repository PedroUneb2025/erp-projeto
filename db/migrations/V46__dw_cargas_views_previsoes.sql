CREATE PROCEDURE dw.sp_carregar_fato_vendas(p_linhas jsonb) LANGUAGE plpgsql AS $$
BEGIN
 IF jsonb_typeof(p_linhas)<>'array' THEN RAISE EXCEPTION 'Esperado array JSON'; END IF;
 INSERT INTO dw.fato_vendas(origem,origem_id,tempo_id,cliente_id,produto_id,quantidade,valor) SELECT origem,origem_id,tempo_id,cliente_id,produto_id,quantidade,valor
 FROM jsonb_to_recordset(p_linhas) AS x(origem text,origem_id text,tempo_id bigint,cliente_id bigint,produto_id bigint,quantidade numeric,valor numeric)
 ON CONFLICT(origem,origem_id) DO UPDATE SET tempo_id=excluded.tempo_id,cliente_id=excluded.cliente_id,produto_id=excluded.produto_id,quantidade=excluded.quantidade,valor=excluded.valor,updated_at=now(),deleted_at=NULL;
END $$;
CREATE PROCEDURE dw.sp_carregar_fato_financeiro(p_linhas jsonb) LANGUAGE plpgsql AS $$
BEGIN
 IF jsonb_typeof(p_linhas)<>'array' THEN RAISE EXCEPTION 'Esperado array JSON'; END IF;
 INSERT INTO dw.fato_financeiro(origem,origem_id,tempo_id,categoria,tipo,valor) SELECT origem,origem_id,tempo_id,categoria,tipo,valor
 FROM jsonb_to_recordset(p_linhas) AS x(origem text,origem_id text,tempo_id bigint,categoria text,tipo text,valor numeric)
 ON CONFLICT(origem,origem_id) DO UPDATE SET tempo_id=excluded.tempo_id,categoria=excluded.categoria,tipo=excluded.tipo,valor=excluded.valor,updated_at=now(),deleted_at=NULL;
END $$;
CREATE PROCEDURE dw.sp_carregar_fato_estoque(p_linhas jsonb) LANGUAGE plpgsql AS $$
BEGIN
 IF jsonb_typeof(p_linhas)<>'array' THEN RAISE EXCEPTION 'Esperado array JSON'; END IF;
 INSERT INTO dw.fato_estoque(origem,origem_id,tempo_id,produto_id,fornecedor_id,quantidade,valor) SELECT origem,origem_id,tempo_id,produto_id,fornecedor_id,quantidade,valor
 FROM jsonb_to_recordset(p_linhas) AS x(origem text,origem_id text,tempo_id bigint,produto_id bigint,fornecedor_id bigint,quantidade numeric,valor numeric)
 ON CONFLICT(origem,origem_id) DO UPDATE SET tempo_id=excluded.tempo_id,produto_id=excluded.produto_id,fornecedor_id=excluded.fornecedor_id,quantidade=excluded.quantidade,valor=excluded.valor,updated_at=now(),deleted_at=NULL;
END $$;
CREATE PROCEDURE dw.sp_carregar_fato_producao(p_linhas jsonb) LANGUAGE plpgsql AS $$
BEGIN
 IF jsonb_typeof(p_linhas)<>'array' THEN RAISE EXCEPTION 'Esperado array JSON'; END IF;
 INSERT INTO dw.fato_producao(origem,origem_id,tempo_id,produto_id,quantidade,perdas) SELECT origem,origem_id,tempo_id,produto_id,quantidade,perdas
 FROM jsonb_to_recordset(p_linhas) AS x(origem text,origem_id text,tempo_id bigint,produto_id bigint,quantidade numeric,perdas numeric)
 ON CONFLICT(origem,origem_id) DO UPDATE SET tempo_id=excluded.tempo_id,produto_id=excluded.produto_id,quantidade=excluded.quantidade,perdas=excluded.perdas,updated_at=now(),deleted_at=NULL;
END $$;
CREATE TRIGGER trg_dim_tempo_auditoria BEFORE INSERT OR UPDATE OR DELETE ON dw.dim_tempo FOR EACH ROW EXECUTE FUNCTION sys.fn_auditar();
CREATE TRIGGER trg_dim_clientes_auditoria BEFORE INSERT OR UPDATE OR DELETE ON dw.dim_clientes FOR EACH ROW EXECUTE FUNCTION sys.fn_auditar();
CREATE TRIGGER trg_dim_produtos_auditoria BEFORE INSERT OR UPDATE OR DELETE ON dw.dim_produtos FOR EACH ROW EXECUTE FUNCTION sys.fn_auditar();
CREATE TRIGGER trg_dim_fornecedores_auditoria BEFORE INSERT OR UPDATE OR DELETE ON dw.dim_fornecedores FOR EACH ROW EXECUTE FUNCTION sys.fn_auditar();
CREATE TRIGGER trg_fato_vendas_auditoria BEFORE INSERT OR UPDATE OR DELETE ON dw.fato_vendas FOR EACH ROW EXECUTE FUNCTION sys.fn_auditar();
CREATE TRIGGER trg_fato_financeiro_auditoria BEFORE INSERT OR UPDATE OR DELETE ON dw.fato_financeiro FOR EACH ROW EXECUTE FUNCTION sys.fn_auditar();
CREATE TRIGGER trg_fato_estoque_auditoria BEFORE INSERT OR UPDATE OR DELETE ON dw.fato_estoque FOR EACH ROW EXECUTE FUNCTION sys.fn_auditar();
CREATE TRIGGER trg_fato_producao_auditoria BEFORE INSERT OR UPDATE OR DELETE ON dw.fato_producao FOR EACH ROW EXECUTE FUNCTION sys.fn_auditar();
CREATE VIEW dw.vw_vendas_por_mes AS SELECT dw.fn_mes(t.data) mes,sum(f.valor) receita,sum(f.quantidade) quantidade FROM dw.fato_vendas f JOIN dw.dim_tempo t ON t.id=f.tempo_id WHERE f.deleted_at IS NULL GROUP BY 1;
CREATE VIEW dw.vw_financeiro_por_mes AS SELECT dw.fn_mes(t.data) mes,sum(CASE WHEN f.tipo='entrada' THEN f.valor ELSE -f.valor END) saldo FROM dw.fato_financeiro f JOIN dw.dim_tempo t ON t.id=f.tempo_id WHERE f.deleted_at IS NULL GROUP BY 1;
CREATE VIEW dw.vw_estoque_atual AS SELECT DISTINCT ON(f.produto_id) f.produto_id,p.nome,t.data,f.quantidade,f.valor FROM dw.fato_estoque f JOIN dw.dim_tempo t ON t.id=f.tempo_id JOIN dw.dim_produtos p ON p.id=f.produto_id WHERE f.deleted_at IS NULL ORDER BY f.produto_id,t.data DESC,f.id DESC;
CREATE VIEW dw.vw_producao_por_mes AS SELECT dw.fn_mes(t.data) mes,sum(f.quantidade) quantidade,sum(f.perdas) perdas FROM dw.fato_producao f JOIN dw.dim_tempo t ON t.id=f.tempo_id WHERE f.deleted_at IS NULL GROUP BY 1;
CREATE TABLE dw.previsoes_demanda (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 created_by bigint, deleted_at timestamptz,
 produto_id bigint NOT NULL REFERENCES dw.dim_produtos(id), data date NOT NULL, quantidade numeric(16,4) NOT NULL CHECK(quantidade>=0), modelo text NOT NULL, mae numeric(16,4), treinado_ate date NOT NULL, UNIQUE(produto_id,data)
);
CREATE INDEX ix_previsoes_demanda_produto_id ON dw.previsoes_demanda(produto_id);

CREATE TRIGGER trg_previsoes_demanda_auditoria BEFORE INSERT OR UPDATE OR DELETE ON dw.previsoes_demanda FOR EACH ROW EXECUTE FUNCTION sys.fn_auditar();
