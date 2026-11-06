CREATE TABLE dw.fato_vendas (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 created_by bigint, deleted_at timestamptz,
 origem text NOT NULL, origem_id text NOT NULL, tempo_id bigint NOT NULL REFERENCES dw.dim_tempo(id), cliente_id bigint NOT NULL REFERENCES dw.dim_clientes(id), produto_id bigint NOT NULL REFERENCES dw.dim_produtos(id), quantidade numeric(16,4) NOT NULL CHECK(quantidade>=0), valor numeric(16,2) NOT NULL CHECK(valor>=0), UNIQUE(origem,origem_id)
);
CREATE INDEX ix_fato_vendas_tempo_id ON dw.fato_vendas(tempo_id);
CREATE INDEX ix_fato_vendas_produto_id ON dw.fato_vendas(produto_id);
CREATE TABLE dw.fato_financeiro (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 created_by bigint, deleted_at timestamptz,
 origem text NOT NULL, origem_id text NOT NULL, tempo_id bigint NOT NULL REFERENCES dw.dim_tempo(id), categoria text NOT NULL, tipo text NOT NULL CHECK(tipo IN ('entrada','saida')), valor numeric(16,2) NOT NULL CHECK(valor>=0), UNIQUE(origem,origem_id)
);
CREATE INDEX ix_fato_financeiro_tempo_id ON dw.fato_financeiro(tempo_id);
CREATE TABLE dw.fato_estoque (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 created_by bigint, deleted_at timestamptz,
 origem text NOT NULL, origem_id text NOT NULL, tempo_id bigint NOT NULL REFERENCES dw.dim_tempo(id), produto_id bigint NOT NULL REFERENCES dw.dim_produtos(id), fornecedor_id bigint REFERENCES dw.dim_fornecedores(id), quantidade numeric(16,4) NOT NULL, valor numeric(16,2) NOT NULL, UNIQUE(origem,origem_id)
);
CREATE INDEX ix_fato_estoque_tempo_id ON dw.fato_estoque(tempo_id);
CREATE INDEX ix_fato_estoque_produto_id ON dw.fato_estoque(produto_id);
CREATE TABLE dw.fato_producao (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 created_by bigint, deleted_at timestamptz,
 origem text NOT NULL, origem_id text NOT NULL, tempo_id bigint NOT NULL REFERENCES dw.dim_tempo(id), produto_id bigint NOT NULL REFERENCES dw.dim_produtos(id), quantidade numeric(16,4) NOT NULL CHECK(quantidade>=0), perdas numeric(16,4) NOT NULL DEFAULT 0 CHECK(perdas>=0), UNIQUE(origem,origem_id)
);
CREATE INDEX ix_fato_producao_tempo_id ON dw.fato_producao(tempo_id);
CREATE INDEX ix_fato_producao_produto_id ON dw.fato_producao(produto_id);
CREATE INDEX ix_fato_vendas_cliente_id ON dw.fato_vendas(cliente_id);
CREATE INDEX ix_fato_estoque_fornecedor_id ON dw.fato_estoque(fornecedor_id);
