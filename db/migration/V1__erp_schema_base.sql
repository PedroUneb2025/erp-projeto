CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE SCHEMA IF NOT EXISTS sys;
CREATE SCHEMA IF NOT EXISTS fi;
CREATE SCHEMA IF NOT EXISTS rh;
CREATE SCHEMA IF NOT EXISTS mm;
CREATE SCHEMA IF NOT EXISTS sd;
CREATE SCHEMA IF NOT EXISTS pp;
CREATE SCHEMA IF NOT EXISTS ps;
CREATE SCHEMA IF NOT EXISTS sm;
CREATE SCHEMA IF NOT EXISTS qm;
CREATE SCHEMA IF NOT EXISTS am;
CREATE SCHEMA IF NOT EXISTS grc;
CREATE SCHEMA IF NOT EXISTS api;
CREATE SCHEMA IF NOT EXISTS bi;

CREATE SEQUENCE sd.seq_pedido_venda START 1000;
CREATE SEQUENCE mm.seq_pedido_compra START 5000;
CREATE SEQUENCE pp.seq_ordem_producao START 1;
CREATE SEQUENCE sm.seq_ordem_servico START 1;
CREATE SEQUENCE sd.seq_nota_fiscal START 1;

CREATE TABLE sys.perfil (
  id SERIAL PRIMARY KEY,
  nome VARCHAR(40) UNIQUE NOT NULL,
  descricao TEXT
);
CREATE TABLE sys.permissao (
  id SERIAL PRIMARY KEY,
  modulo VARCHAR(10) NOT NULL,
  recurso VARCHAR(60) NOT NULL,
  acao VARCHAR(10) NOT NULL CHECK (acao IN ('SELECT','INSERT','UPDATE','DELETE','APPROVE')),
  UNIQUE (modulo, recurso, acao)
);
CREATE TABLE sys.perfil_permissao (
  perfil_id INT REFERENCES sys.perfil ON DELETE CASCADE,
  permissao_id INT REFERENCES sys.permissao ON DELETE CASCADE,
  PRIMARY KEY (perfil_id, permissao_id)
);
CREATE TABLE sys.usuario (
  id SERIAL PRIMARY KEY,
  login VARCHAR(50) UNIQUE NOT NULL,
  email VARCHAR(120) UNIQUE NOT NULL,
  senha_hash TEXT NOT NULL,
  ativo BOOLEAN NOT NULL DEFAULT TRUE,
  ultimo_acesso TIMESTAMPTZ,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE sys.usuario_perfil (
  usuario_id INT REFERENCES sys.usuario ON DELETE CASCADE,
  perfil_id INT REFERENCES sys.perfil ON DELETE CASCADE,
  PRIMARY KEY (usuario_id, perfil_id)
);
CREATE TABLE sys.parametro (
  chave VARCHAR(80) PRIMARY KEY, valor TEXT NOT NULL, descricao TEXT
);

CREATE TABLE sys.log_auditoria (
  id BIGINT GENERATED ALWAYS AS IDENTITY,
  data_evento TIMESTAMPTZ NOT NULL DEFAULT now(),
  usuario_db TEXT NOT NULL,
  tabela TEXT NOT NULL,
  operacao VARCHAR(10) NOT NULL,
  dados_antigos JSONB,
  dados_novos JSONB,
  PRIMARY KEY (id, data_evento)
) PARTITION BY RANGE (data_evento);
CREATE TABLE sys.log_auditoria_2025 PARTITION OF sys.log_auditoria
  FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE sys.log_auditoria_2026 PARTITION OF sys.log_auditoria
  FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE sys.log_auditoria_2027 PARTITION OF sys.log_auditoria
  FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE TABLE sys.log_auditoria_2028 PARTITION OF sys.log_auditoria
  FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');
CREATE TABLE sys.log_auditoria_default PARTITION OF sys.log_auditoria DEFAULT;
-- Recompõe permissões nas partições criadas dinamicamente
ALTER DEFAULT PRIVILEGES FOR ROLE CURRENT_USER IN SCHEMA sys
  REVOKE ALL ON TABLES FROM PUBLIC;
CREATE INDEX ix_log_tabela_data ON sys.log_auditoria (tabela, data_evento DESC);

CREATE OR REPLACE FUNCTION sys.fn_auditoria() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO sys.log_auditoria(usuario_db, tabela, operacao, dados_antigos, dados_novos)
  VALUES (session_user, TG_TABLE_SCHEMA||'.'||TG_TABLE_NAME, TG_OP,
          CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) END,
          CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) END);
  RETURN COALESCE(NEW, OLD);
END $$;

CREATE TABLE fi.plano_contas (
  id SERIAL PRIMARY KEY,
  codigo VARCHAR(20) UNIQUE NOT NULL,
  descricao VARCHAR(120) NOT NULL,
  tipo CHAR(1) NOT NULL CHECK (tipo IN ('A','P','R','D')),
  pai_id INT REFERENCES fi.plano_contas
);
CREATE TABLE fi.conta_bancaria (
  id SERIAL PRIMARY KEY,
  banco VARCHAR(60) NOT NULL, agencia VARCHAR(10), numero VARCHAR(20),
  saldo NUMERIC(15,2) NOT NULL DEFAULT 0
);
CREATE TABLE fi.lancamento (
  id BIGSERIAL PRIMARY KEY,
  data_lancamento DATE NOT NULL DEFAULT CURRENT_DATE,
  conta_debito INT NOT NULL REFERENCES fi.plano_contas,
  conta_credito INT NOT NULL REFERENCES fi.plano_contas,
  valor NUMERIC(15,2) NOT NULL CHECK (valor > 0),
  historico TEXT,
  CHECK (conta_debito <> conta_credito)
);
CREATE TABLE fi.conta_pagar (
  id BIGSERIAL PRIMARY KEY,
  fornecedor_id INT, descricao TEXT,
  valor NUMERIC(15,2) NOT NULL CHECK (valor > 0),
  vencimento DATE NOT NULL, pagamento DATE,
  status VARCHAR(10) NOT NULL DEFAULT 'ABERTA' CHECK (status IN ('ABERTA','PAGA','CANCELADA'))
);
CREATE TABLE fi.conta_receber (
  id BIGSERIAL PRIMARY KEY,
  cliente_id INT, pedido_id INT,
  valor NUMERIC(15,2) NOT NULL CHECK (valor > 0),
  vencimento DATE NOT NULL, recebimento DATE,
  status VARCHAR(10) NOT NULL DEFAULT 'ABERTA' CHECK (status IN ('ABERTA','RECEBIDA','CANCELADA'))
);
CREATE TABLE fi.orcamento (
  id SERIAL PRIMARY KEY, centro_custo VARCHAR(40) NOT NULL, ano INT NOT NULL,
  valor_previsto NUMERIC(15,2) NOT NULL, UNIQUE (centro_custo, ano)
);

CREATE TABLE rh.departamento (
  id SERIAL PRIMARY KEY, nome VARCHAR(60) UNIQUE NOT NULL, gerente_id INT
);
CREATE TABLE rh.cargo (
  id SERIAL PRIMARY KEY, nome VARCHAR(60) UNIQUE NOT NULL,
  nivel VARCHAR(12) NOT NULL CHECK (nivel IN ('CEO','DIRETOR','GERENTE','SUPERVISOR','ANALISTA','OPERACIONAL')),
  salario_base NUMERIC(12,2) NOT NULL
);
CREATE TABLE rh.colaborador (
  id SERIAL PRIMARY KEY,
  usuario_id INT REFERENCES sys.usuario,
  nome VARCHAR(120) NOT NULL,
  cpf_hash TEXT UNIQUE NOT NULL,
  cpf_cript BYTEA NOT NULL,
  departamento_id INT REFERENCES rh.departamento,
  cargo_id INT REFERENCES rh.cargo,
  admissao DATE NOT NULL, demissao DATE,
  ativo BOOLEAN NOT NULL DEFAULT TRUE
);
ALTER TABLE rh.departamento ADD FOREIGN KEY (gerente_id) REFERENCES rh.colaborador;
CREATE TABLE rh.ponto (
  id BIGSERIAL PRIMARY KEY,
  colaborador_id INT NOT NULL REFERENCES rh.colaborador,
  entrada TIMESTAMPTZ NOT NULL, saida TIMESTAMPTZ,
  CHECK (saida IS NULL OR saida > entrada)
);
CREATE TABLE rh.folha_pagamento (
  id BIGSERIAL PRIMARY KEY,
  colaborador_id INT NOT NULL REFERENCES rh.colaborador,
  competencia DATE NOT NULL,
  bruto NUMERIC(12,2) NOT NULL, inss NUMERIC(12,2) NOT NULL DEFAULT 0,
  irrf NUMERIC(12,2) NOT NULL DEFAULT 0, beneficios NUMERIC(12,2) NOT NULL DEFAULT 0,
  liquido NUMERIC(12,2) GENERATED ALWAYS AS (bruto - inss - irrf + beneficios) STORED,
  UNIQUE (colaborador_id, competencia)
);
CREATE TABLE rh.avaliacao_desempenho (
  id SERIAL PRIMARY KEY, colaborador_id INT NOT NULL REFERENCES rh.colaborador,
  periodo VARCHAR(7) NOT NULL, nota NUMERIC(3,1) CHECK (nota BETWEEN 0 AND 10), parecer TEXT
);

CREATE TABLE mm.fornecedor (
  id SERIAL PRIMARY KEY, razao_social VARCHAR(150) NOT NULL,
  cnpj CHAR(14) UNIQUE NOT NULL, email VARCHAR(120), ativo BOOLEAN DEFAULT TRUE
);
CREATE TABLE mm.material (
  id SERIAL PRIMARY KEY, sku VARCHAR(30) UNIQUE NOT NULL, descricao VARCHAR(150) NOT NULL,
  unidade VARCHAR(5) NOT NULL, custo_medio NUMERIC(12,4) NOT NULL DEFAULT 0,
  preco_venda NUMERIC(12,2), estoque_minimo NUMERIC(12,3) NOT NULL DEFAULT 0,
  tipo VARCHAR(10) NOT NULL DEFAULT 'COMPRA' CHECK (tipo IN ('COMPRA','PRODUCAO','SERVICO'))
);
CREATE TABLE mm.deposito (id SERIAL PRIMARY KEY, nome VARCHAR(60) UNIQUE NOT NULL);
CREATE TABLE mm.estoque (
  material_id INT REFERENCES mm.material, deposito_id INT REFERENCES mm.deposito,
  quantidade NUMERIC(14,3) NOT NULL DEFAULT 0 CHECK (quantidade >= 0),
  PRIMARY KEY (material_id, deposito_id)
);
CREATE TABLE mm.movimento_estoque (
  id BIGSERIAL PRIMARY KEY,
  material_id INT NOT NULL REFERENCES mm.material,
  deposito_id INT NOT NULL REFERENCES mm.deposito,
  tipo CHAR(1) NOT NULL CHECK (tipo IN ('E','S')),
  quantidade NUMERIC(14,3) NOT NULL CHECK (quantidade > 0),
  origem VARCHAR(30), documento_id BIGINT,
  data_mov TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE mm.pedido_compra (
  id INT PRIMARY KEY DEFAULT nextval('mm.seq_pedido_compra'),
  fornecedor_id INT NOT NULL REFERENCES mm.fornecedor,
  data_pedido DATE NOT NULL DEFAULT CURRENT_DATE,
  status VARCHAR(12) NOT NULL DEFAULT 'ABERTO' CHECK (status IN ('ABERTO','APROVADO','RECEBIDO','CANCELADO'))
);
CREATE TABLE mm.item_pedido_compra (
  pedido_id INT REFERENCES mm.pedido_compra ON DELETE CASCADE,
  material_id INT REFERENCES mm.material,
  quantidade NUMERIC(14,3) NOT NULL CHECK (quantidade > 0),
  preco_unit NUMERIC(12,4) NOT NULL,
  PRIMARY KEY (pedido_id, material_id)
);
ALTER TABLE fi.conta_pagar ADD FOREIGN KEY (fornecedor_id) REFERENCES mm.fornecedor;

CREATE TABLE sd.cliente (
  id SERIAL PRIMARY KEY, nome VARCHAR(150) NOT NULL,
  documento VARCHAR(14) UNIQUE NOT NULL, email VARCHAR(120), telefone VARCHAR(20),
  limite_credito NUMERIC(14,2) NOT NULL DEFAULT 0, criado_em TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE sd.oportunidade (
  id SERIAL PRIMARY KEY, cliente_id INT NOT NULL REFERENCES sd.cliente,
  responsavel_id INT REFERENCES rh.colaborador, valor_estimado NUMERIC(14,2),
  etapa VARCHAR(15) NOT NULL DEFAULT 'LEAD'
    CHECK (etapa IN ('LEAD','QUALIFICADO','PROPOSTA','NEGOCIACAO','GANHO','PERDIDO'))
);
CREATE TABLE sd.contrato (
  id SERIAL PRIMARY KEY, cliente_id INT NOT NULL REFERENCES sd.cliente,
  inicio DATE NOT NULL, fim DATE, valor_mensal NUMERIC(14,2), hash_blockchain TEXT
);
CREATE TABLE sd.pedido_venda (
  id INT PRIMARY KEY DEFAULT nextval('sd.seq_pedido_venda'),
  cliente_id INT NOT NULL REFERENCES sd.cliente,
  vendedor_id INT REFERENCES rh.colaborador,
  data_pedido DATE NOT NULL DEFAULT CURRENT_DATE,
  status VARCHAR(12) NOT NULL DEFAULT 'ABERTO'
    CHECK (status IN ('ABERTO','APROVADO','FATURADO','CANCELADO')),
  total NUMERIC(14,2) NOT NULL DEFAULT 0
);
CREATE TABLE sd.item_pedido_venda (
  pedido_id INT REFERENCES sd.pedido_venda ON DELETE CASCADE,
  material_id INT REFERENCES mm.material,
  quantidade NUMERIC(14,3) NOT NULL CHECK (quantidade > 0),
  preco_unit NUMERIC(12,2) NOT NULL,
  PRIMARY KEY (pedido_id, material_id)
);
CREATE TABLE sd.nota_fiscal (
  id INT PRIMARY KEY DEFAULT nextval('sd.seq_nota_fiscal'),
  pedido_id INT UNIQUE NOT NULL REFERENCES sd.pedido_venda,
  emissao TIMESTAMPTZ NOT NULL DEFAULT now(), valor NUMERIC(14,2) NOT NULL,
  chave_nfe CHAR(44) UNIQUE
);
ALTER TABLE fi.conta_receber ADD FOREIGN KEY (cliente_id) REFERENCES sd.cliente;
ALTER TABLE fi.conta_receber ADD FOREIGN KEY (pedido_id) REFERENCES sd.pedido_venda;

CREATE TABLE pp.bom (
  produto_id INT REFERENCES mm.material, componente_id INT REFERENCES mm.material,
  quantidade NUMERIC(14,4) NOT NULL CHECK (quantidade > 0),
  PRIMARY KEY (produto_id, componente_id), CHECK (produto_id <> componente_id)
);
CREATE TABLE pp.ordem_producao (
  id INT PRIMARY KEY DEFAULT nextval('pp.seq_ordem_producao'),
  produto_id INT NOT NULL REFERENCES mm.material, quantidade NUMERIC(14,3) NOT NULL,
  inicio_previsto DATE, fim_previsto DATE,
  status VARCHAR(12) NOT NULL DEFAULT 'PLANEJADA'
    CHECK (status IN ('PLANEJADA','LIBERADA','EM_ANDAMENTO','CONCLUIDA','CANCELADA'))
);

CREATE TABLE ps.projeto (
  id SERIAL PRIMARY KEY, nome VARCHAR(120) NOT NULL, gerente_id INT REFERENCES rh.colaborador,
  orcamento NUMERIC(15,2), inicio DATE, fim DATE,
  status VARCHAR(12) DEFAULT 'PLANEJADO'
);
CREATE TABLE ps.tarefa (
  id SERIAL PRIMARY KEY, projeto_id INT NOT NULL REFERENCES ps.projeto ON DELETE CASCADE,
  descricao TEXT NOT NULL, responsavel_id INT REFERENCES rh.colaborador,
  inicio DATE, fim DATE, percentual INT DEFAULT 0 CHECK (percentual BETWEEN 0 AND 100)
);
CREATE TABLE sm.ordem_servico (
  id INT PRIMARY KEY DEFAULT nextval('sm.seq_ordem_servico'),
  cliente_id INT NOT NULL REFERENCES sd.cliente, tecnico_id INT REFERENCES rh.colaborador,
  descricao TEXT NOT NULL, aberta_em TIMESTAMPTZ DEFAULT now(),
  prazo_sla TIMESTAMPTZ, fechada_em TIMESTAMPTZ,
  status VARCHAR(12) NOT NULL DEFAULT 'ABERTA'
);
CREATE TABLE qm.inspecao (
  id SERIAL PRIMARY KEY, material_id INT NOT NULL REFERENCES mm.material,
  tipo VARCHAR(12) NOT NULL CHECK (tipo IN ('RECEBIMENTO','PRODUCAO','EXPEDICAO')),
  lote VARCHAR(30), aprovado BOOLEAN, data_insp TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE qm.nao_conformidade (
  id SERIAL PRIMARY KEY, inspecao_id INT REFERENCES qm.inspecao,
  descricao TEXT NOT NULL, acao_corretiva TEXT, resolvida BOOLEAN DEFAULT FALSE
);
CREATE TABLE am.ativo (
  id SERIAL PRIMARY KEY, descricao VARCHAR(120) NOT NULL,
  valor_aquisicao NUMERIC(15,2) NOT NULL, data_aquisicao DATE NOT NULL,
  vida_util_meses INT NOT NULL CHECK (vida_util_meses > 0),
  depreciacao_acumulada NUMERIC(15,2) NOT NULL DEFAULT 0
);
CREATE TABLE am.manutencao (
  id SERIAL PRIMARY KEY, ativo_id INT NOT NULL REFERENCES am.ativo,
  tipo VARCHAR(12) CHECK (tipo IN ('PREVENTIVA','CORRETIVA')),
  data_manut DATE, custo NUMERIC(12,2)
);
CREATE TABLE grc.risco (
  id SERIAL PRIMARY KEY, descricao TEXT NOT NULL,
  probabilidade INT CHECK (probabilidade BETWEEN 1 AND 5),
  impacto INT CHECK (impacto BETWEEN 1 AND 5),
  severidade INT GENERATED ALWAYS AS (probabilidade * impacto) STORED,
  mitigacao TEXT
);
CREATE TABLE grc.consentimento_lgpd (
  id SERIAL PRIMARY KEY, titular_tipo VARCHAR(12), titular_id INT NOT NULL,
  finalidade TEXT NOT NULL, consentido BOOLEAN NOT NULL, data_registro TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE api.integracao_log (
  id BIGSERIAL PRIMARY KEY, sistema VARCHAR(40) NOT NULL, endpoint TEXT,
  payload JSONB, status_http INT, criado_em TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE api.leitura_iot (
  id BIGSERIAL PRIMARY KEY, dispositivo VARCHAR(40) NOT NULL,
  grandeza VARCHAR(20), valor NUMERIC, lida_em TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_pv_cliente ON sd.pedido_venda (cliente_id, data_pedido DESC);
CREATE INDEX ix_pv_status ON sd.pedido_venda (status) WHERE status <> 'FATURADO';
CREATE INDEX ix_cr_venc ON fi.conta_receber (vencimento) WHERE status = 'ABERTA';
CREATE INDEX ix_cp_venc ON fi.conta_pagar (vencimento) WHERE status = 'ABERTA';
CREATE INDEX ix_mov_material ON mm.movimento_estoque (material_id, data_mov DESC);
CREATE INDEX ix_cliente_nome ON sd.cliente USING gin (nome gin_trgm_ops);
CREATE INDEX ix_material_desc ON mm.material USING gin (descricao gin_trgm_ops);
CREATE INDEX ix_os_status ON sm.ordem_servico (status, prazo_sla);
CREATE INDEX ix_iot_disp ON api.leitura_iot (dispositivo, lida_em DESC);
CREATE INDEX ix_payload_gin ON api.integracao_log USING gin (payload);

CREATE OR REPLACE FUNCTION mm.fn_atualiza_estoque() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO mm.estoque (material_id, deposito_id, quantidade)
  VALUES (NEW.material_id, NEW.deposito_id, 0)
  ON CONFLICT DO NOTHING;
  UPDATE mm.estoque
     SET quantidade = quantidade + CASE NEW.tipo WHEN 'E' THEN NEW.quantidade ELSE -NEW.quantidade END
   WHERE material_id = NEW.material_id AND deposito_id = NEW.deposito_id;
  RETURN NEW;
EXCEPTION WHEN check_violation THEN
  RAISE EXCEPTION 'Estoque insuficiente para o material %', NEW.material_id;
END $$;
CREATE TRIGGER trg_movimento_estoque AFTER INSERT ON mm.movimento_estoque
FOR EACH ROW EXECUTE FUNCTION mm.fn_atualiza_estoque();

CREATE OR REPLACE FUNCTION sd.fn_recalcula_total() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_pedido INT := COALESCE(NEW.pedido_id, OLD.pedido_id);
BEGIN
  UPDATE sd.pedido_venda
     SET total = COALESCE((SELECT SUM(quantidade*preco_unit) FROM sd.item_pedido_venda
                            WHERE pedido_id = v_pedido), 0)
   WHERE id = v_pedido;
  RETURN NULL;
END $$;
CREATE TRIGGER trg_total_pedido AFTER INSERT OR UPDATE OR DELETE ON sd.item_pedido_venda
FOR EACH ROW EXECUTE FUNCTION sd.fn_recalcula_total();

CREATE OR REPLACE FUNCTION sd.fn_bloqueia_faturado() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.status = 'FATURADO' AND NEW.status <> 'FATURADO' THEN
    RAISE EXCEPTION 'Pedido % já faturado: alteração proibida', OLD.id;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_bloqueia_faturado BEFORE UPDATE ON sd.pedido_venda
FOR EACH ROW EXECUTE FUNCTION sd.fn_bloqueia_faturado();

CREATE OR REPLACE FUNCTION rh.fn_calcula_inss(p_bruto NUMERIC) RETURNS NUMERIC
LANGUAGE sql IMMUTABLE AS $$
  SELECT ROUND(CASE WHEN p_bruto <= 1518    THEN p_bruto*0.075
                    WHEN p_bruto <= 2793.88 THEN p_bruto*0.09
                    WHEN p_bruto <= 4190.83 THEN p_bruto*0.12
                    ELSE LEAST(p_bruto,8157.41)*0.14 END, 2) $$;

CREATE OR REPLACE FUNCTION rh.fn_cadastra_colaborador(
  p_nome TEXT, p_cpf TEXT, p_depto INT, p_cargo INT, p_chave TEXT) RETURNS INT
LANGUAGE plpgsql AS $$
DECLARE v_id INT;
BEGIN
  INSERT INTO rh.colaborador (nome, cpf_hash, cpf_cript, departamento_id, cargo_id, admissao)
  VALUES (p_nome, encode(digest(p_cpf,'sha256'),'hex'), pgp_sym_encrypt(p_cpf, p_chave),
          p_depto, p_cargo, CURRENT_DATE)
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE OR REPLACE PROCEDURE sd.sp_faturar_pedido(p_pedido INT, p_deposito INT, p_dias_venc INT DEFAULT 30)
LANGUAGE plpgsql AS $$
DECLARE v_ped sd.pedido_venda%ROWTYPE; r RECORD;
BEGIN
  SELECT * INTO v_ped FROM sd.pedido_venda WHERE id = p_pedido FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Pedido % inexistente', p_pedido; END IF;
  IF v_ped.status <> 'APROVADO' THEN
    RAISE EXCEPTION 'Pedido % precisa estar APROVADO (atual: %)', p_pedido, v_ped.status;
  END IF;
  FOR r IN SELECT material_id, quantidade FROM sd.item_pedido_venda WHERE pedido_id = p_pedido LOOP
    INSERT INTO mm.movimento_estoque (material_id, deposito_id, tipo, quantidade, origem, documento_id)
    VALUES (r.material_id, p_deposito, 'S', r.quantidade, 'VENDA', p_pedido);
  END LOOP;
  INSERT INTO sd.nota_fiscal (pedido_id, valor) VALUES (p_pedido, v_ped.total);
  INSERT INTO fi.conta_receber (cliente_id, pedido_id, valor, vencimento)
  VALUES (v_ped.cliente_id, p_pedido, v_ped.total, CURRENT_DATE + p_dias_venc);
  UPDATE sd.pedido_venda SET status = 'FATURADO' WHERE id = p_pedido;
END $$;

CREATE OR REPLACE PROCEDURE mm.sp_receber_compra(p_pedido INT, p_deposito INT, p_dias_venc INT DEFAULT 30)
LANGUAGE plpgsql AS $$
DECLARE v_forn INT; v_total NUMERIC; r RECORD;
BEGIN
  SELECT fornecedor_id INTO v_forn FROM mm.pedido_compra
   WHERE id = p_pedido AND status = 'APROVADO' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Pedido de compra % não está APROVADO', p_pedido; END IF;
  FOR r IN SELECT * FROM mm.item_pedido_compra WHERE pedido_id = p_pedido LOOP
    INSERT INTO mm.movimento_estoque (material_id, deposito_id, tipo, quantidade, origem, documento_id)
    VALUES (r.material_id, p_deposito, 'E', r.quantidade, 'COMPRA', p_pedido);
  END LOOP;
  SELECT SUM(quantidade*preco_unit) INTO v_total FROM mm.item_pedido_compra WHERE pedido_id = p_pedido;
  INSERT INTO fi.conta_pagar (fornecedor_id, descricao, valor, vencimento)
  VALUES (v_forn, 'Compra #'||p_pedido, v_total, CURRENT_DATE + p_dias_venc);
  UPDATE mm.pedido_compra SET status = 'RECEBIDO' WHERE id = p_pedido;
END $$;

CREATE OR REPLACE PROCEDURE am.sp_depreciar_ativos()
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE am.ativo
     SET depreciacao_acumulada = LEAST(valor_aquisicao,
           depreciacao_acumulada + ROUND(valor_aquisicao / vida_util_meses, 2))
   WHERE depreciacao_acumulada < valor_aquisicao;
END $$;

CREATE OR REPLACE PROCEDURE rh.sp_gerar_folha(p_competencia DATE)
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO rh.folha_pagamento (colaborador_id, competencia, bruto, inss)
  SELECT c.id, date_trunc('month', p_competencia)::date, g.salario_base,
         rh.fn_calcula_inss(g.salario_base)
    FROM rh.colaborador c JOIN rh.cargo g ON g.id = c.cargo_id
   WHERE c.ativo
  ON CONFLICT (colaborador_id, competencia) DO NOTHING;
END $$;

CREATE OR REPLACE PROCEDURE fi.sp_baixar_recebimento(p_id BIGINT, p_conta_banco INT)
LANGUAGE plpgsql AS $$
DECLARE v_valor NUMERIC;
BEGIN
  UPDATE fi.conta_receber SET status='RECEBIDA', recebimento=CURRENT_DATE
   WHERE id = p_id AND status='ABERTA' RETURNING valor INTO v_valor;
  IF NOT FOUND THEN RAISE EXCEPTION 'Título % não está em aberto', p_id; END IF;
  UPDATE fi.conta_bancaria SET saldo = saldo + v_valor WHERE id = p_conta_banco;
END $$;

CREATE VIEW bi.vw_vendas_mensais AS
SELECT date_trunc('month', data_pedido)::date AS mes, COUNT(*) AS pedidos, SUM(total) AS faturamento
  FROM sd.pedido_venda WHERE status = 'FATURADO' GROUP BY 1;

CREATE VIEW bi.vw_estoque_critico AS
SELECT m.sku, m.descricao, SUM(e.quantidade) AS saldo, m.estoque_minimo
  FROM mm.material m JOIN mm.estoque e ON e.material_id = m.id
 GROUP BY m.id HAVING SUM(e.quantidade) < m.estoque_minimo;

CREATE VIEW bi.vw_fluxo_caixa AS
SELECT d AS data, SUM(entrada) AS entradas, SUM(saida) AS saidas, SUM(entrada-saida) AS saldo_dia
  FROM (SELECT vencimento d, valor entrada, 0::numeric saida FROM fi.conta_receber WHERE status='ABERTA'
        UNION ALL
        SELECT vencimento, 0, valor FROM fi.conta_pagar WHERE status='ABERTA') t
 GROUP BY d ORDER BY d;

CREATE VIEW bi.vw_inadimplencia AS
SELECT c.nome, SUM(r.valor) AS total_vencido, MIN(r.vencimento) AS mais_antigo
  FROM fi.conta_receber r JOIN sd.cliente c ON c.id = r.cliente_id
 WHERE r.status='ABERTA' AND r.vencimento < CURRENT_DATE GROUP BY c.nome;

CREATE VIEW bi.vw_sla_servicos AS
SELECT status, COUNT(*) AS total,
       COUNT(*) FILTER (WHERE COALESCE(fechada_em, now()) > prazo_sla) AS fora_do_sla
  FROM sm.ordem_servico GROUP BY status;

CREATE VIEW rh.vw_colaborador_publico AS
SELECT c.id, c.nome, d.nome AS departamento, g.nome AS cargo, c.ativo
  FROM rh.colaborador c
  LEFT JOIN rh.departamento d ON d.id = c.departamento_id
  LEFT JOIN rh.cargo g ON g.id = c.cargo_id;

CREATE MATERIALIZED VIEW bi.mv_margem_produto AS
SELECT m.sku, SUM(i.quantidade) AS qtd_vendida,
       SUM(i.quantidade*(i.preco_unit - m.custo_medio)) AS margem
  FROM sd.item_pedido_venda i JOIN mm.material m ON m.id = i.material_id
  JOIN sd.pedido_venda p ON p.id = i.pedido_id AND p.status='FATURADO'
 GROUP BY m.sku;
CREATE UNIQUE INDEX ON bi.mv_margem_produto (sku);

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'sys.usuario','sys.usuario_perfil','sys.perfil_permissao',
    'fi.lancamento','fi.conta_pagar','fi.conta_receber','fi.conta_bancaria',
    'rh.colaborador','rh.folha_pagamento','mm.material','mm.pedido_compra',
    'sd.cliente','sd.pedido_venda','sd.nota_fiscal','sd.contrato','am.ativo']
  LOOP
    EXECUTE format('CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON %s
                    FOR EACH ROW EXECUTE FUNCTION sys.fn_auditoria()', t);
  END LOOP;
END $$;

CREATE ROLE erp_dba   NOLOGIN;
CREATE ROLE erp_ceo   NOLOGIN;
CREATE ROLE erp_diretor    NOLOGIN;
CREATE ROLE erp_gerente    NOLOGIN;
CREATE ROLE erp_supervisor NOLOGIN;
CREATE ROLE erp_analista   NOLOGIN;

DO $$
DECLARE s TEXT;
BEGIN
  FOREACH s IN ARRAY ARRAY['sys','fi','rh','mm','sd','pp','ps','sm','qm','am','grc','api','bi'] LOOP
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO erp_dba, erp_ceo, erp_diretor, erp_gerente, erp_supervisor, erp_analista', s);
    EXECUTE format('GRANT ALL ON ALL TABLES IN SCHEMA %I TO erp_dba, erp_ceo', s);
    EXECUTE format('GRANT ALL ON ALL SEQUENCES IN SCHEMA %I TO erp_dba, erp_ceo', s);
    EXECUTE format('GRANT EXECUTE ON ALL ROUTINES IN SCHEMA %I TO erp_dba, erp_ceo', s);
  END LOOP;
END $$;

GRANT SELECT ON ALL TABLES IN SCHEMA fi, rh, mm, sd, pp, ps, sm, qm, am, grc, bi TO erp_diretor;
GRANT UPDATE (status) ON sd.pedido_venda, mm.pedido_compra TO erp_diretor;

GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA mm, sd, pp, ps, sm, qm TO erp_gerente;
GRANT SELECT ON ALL TABLES IN SCHEMA fi, bi TO erp_gerente;
GRANT SELECT ON rh.vw_colaborador_publico TO erp_gerente;
GRANT EXECUTE ON PROCEDURE sd.sp_faturar_pedido, mm.sp_receber_compra TO erp_gerente;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA mm, sd, pp, sm TO erp_gerente, erp_supervisor;

GRANT SELECT, INSERT, UPDATE ON sd.pedido_venda, sd.item_pedido_venda, mm.movimento_estoque,
      pp.ordem_producao, sm.ordem_servico, qm.inspecao, qm.nao_conformidade, ps.tarefa TO erp_supervisor;
GRANT SELECT ON sd.cliente, mm.material, mm.estoque, bi.vw_estoque_critico, bi.vw_sla_servicos TO erp_supervisor;
GRANT SELECT ON rh.vw_colaborador_publico TO erp_supervisor;

GRANT SELECT ON ALL TABLES IN SCHEMA bi TO erp_analista;

REVOKE ALL ON sys.log_auditoria FROM erp_diretor, erp_gerente, erp_supervisor, erp_analista;
REVOKE ALL ON rh.folha_pagamento, rh.colaborador FROM erp_gerente, erp_supervisor, erp_analista;

INSERT INTO sys.perfil (nome, descricao) VALUES
 ('CEO','Acesso total'),('DBA','Acesso total técnico'),('DIRETOR','Visão gerencial'),
 ('GERENTE','Gestão de área'),('SUPERVISOR','Operação'),('ANALISTA','Consulta BI');
INSERT INTO rh.cargo (nome, nivel, salario_base) VALUES
 ('Chief Executive Officer','CEO',40000),('Diretor Comercial','DIRETOR',25000),
 ('Gerente de Vendas','GERENTE',12000),('Supervisor de Estoque','SUPERVISOR',6000),
 ('Analista de BI','ANALISTA',5500);
INSERT INTO mm.deposito (nome) VALUES ('Principal'),('Filial');
INSERT INTO fi.plano_contas (codigo, descricao, tipo) VALUES
 ('1','Ativo','A'),('2','Passivo','P'),('3','Receitas','R'),('4','Despesas','D');

-- =====================================================================
-- AMPLIAÇÕES (aderência ao projeto): conciliação bancária, fluxo de
-- caixa realizado, fiscal/tributos, benefícios, recrutamento, controle
-- de inventário, MRP + chão de fábrica, plano de amostragem,
-- segregação de funções e monitoramento.
-- =====================================================================

-- 1) FI: conciliação bancária e movimento de caixa
CREATE TABLE fi.extrato_bancario (
  id BIGSERIAL PRIMARY KEY,
  conta_id INT NOT NULL REFERENCES fi.conta_bancaria,
  data_mov DATE NOT NULL,
  identificacao TEXT NOT NULL,          -- nº do documento/lançamento no banco
  valor NUMERIC(15,2) NOT NULL,         -- positivo: crédito, negativo: débito
  conciliado BOOLEAN NOT NULL DEFAULT FALSE,
  lancamento_id BIGINT REFERENCES fi.lancamento,
  UNIQUE (conta_id, data_mov, identificacao)
);
CREATE TABLE fi.movimento_caixa (
  id BIGSERIAL PRIMARY KEY,
  conta_id INT NOT NULL REFERENCES fi.conta_bancaria,
  data_mov DATE NOT NULL DEFAULT CURRENT_DATE,
  tipo CHAR(1) NOT NULL CHECK (tipo IN ('E','S')),
  valor NUMERIC(15,2) NOT NULL CHECK (valor > 0),
  historico TEXT
);
CREATE INDEX ix_extrato_concil ON fi.extrato_bancario (conta_id, conciliado, data_mov);

-- 12) Fiscal: livros, obrigações acessórias e tributos
CREATE TABLE fi.tributo (
  id SERIAL PRIMARY KEY,
  nome VARCHAR(60) NOT NULL UNIQUE,
  tipo VARCHAR(10) NOT NULL CHECK (tipo IN ('DIRETO','INDIRETO')),
  aliquota NUMERIC(5,2)
);
CREATE TABLE fi.obrigacao_acessoria (
  id SERIAL PRIMARY KEY,
  tributo_id INT REFERENCES fi.tributo,
  tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('SPED','EFD','ESOCIAL','DCTF','DARF','OUTRO')),
  competencia VARCHAR(7) NOT NULL,
  entrega_prevista DATE NOT NULL,
  entregue_em DATE,
  status VARCHAR(10) NOT NULL DEFAULT 'PENDENTE' CHECK (status IN ('PENDENTE','ENTREGUE','ATRASADA'))
);
CREATE TABLE fi.imposto_documento (
  nota_id INT NOT NULL REFERENCES sd.nota_fiscal,
  tributo_id INT NOT NULL REFERENCES fi.tributo,
  base_calculo NUMERIC(14,2) NOT NULL,
  valor NUMERIC(14,2) NOT NULL,
  PRIMARY KEY (nota_id, tributo_id)
);
CREATE INDEX ix_oa_pendentes ON fi.obrigacao_acessoria (entrega_prevista) WHERE status = 'PENDENTE';

-- 2) RH: benefícios, recrutamento
CREATE TABLE rh.beneficio (
  id SERIAL PRIMARY KEY, nome VARCHAR(60) UNIQUE NOT NULL,
  tipo VARCHAR(15) CHECK (tipo IN ('ALIMENTACAO','SAUDE','TRANSPORTE','PREVIDENCIA','OUTRO')),
  custo_mensal NUMERIC(12,2) NOT NULL DEFAULT 0
);
CREATE TABLE rh.colaborador_beneficio (
  colaborador_id INT REFERENCES rh.colaborador ON DELETE CASCADE,
  beneficio_id INT REFERENCES rh.beneficio ON DELETE CASCADE,
  inicio DATE NOT NULL, fim DATE,
  PRIMARY KEY (colaborador_id, beneficio_id)
);
CREATE TABLE rh.vaga (
  id SERIAL PRIMARY KEY, cargo_id INT REFERENCES rh.cargo,
  departamento_id INT REFERENCES rh.departamento,
  titulo VARCHAR(120) NOT NULL, quantidade INT NOT NULL DEFAULT 1,
  aberta_em DATE NOT NULL DEFAULT CURRENT_DATE, encerrada_em DATE
);
CREATE TABLE rh.candidato (
  id SERIAL PRIMARY KEY, vaga_id INT REFERENCES rh.vaga ON DELETE CASCADE,
  nome VARCHAR(120) NOT NULL, email VARCHAR(120), curriculo TEXT,
  etapa VARCHAR(15) NOT NULL DEFAULT 'TRIAGEM'
    CHECK (etapa IN ('TRIAGEM','ENTREVISTA','TESTE','PROPOSTA','CONTRATADO','REJEITADO'))
);
CREATE INDEX ix_candidato_etapa ON rh.candidato (vaga_id, etapa);

-- 3) MM: inventário (contagem física) e movimentação interna
CREATE TABLE mm.inventario (
  id SERIAL PRIMARY KEY, deposito_id INT NOT NULL REFERENCES mm.deposito,
  data_inv DATE NOT NULL DEFAULT CURRENT_DATE, status VARCHAR(10) DEFAULT 'ABERTO'
    CHECK (status IN ('ABERTO','ENCERRADO'))
);
CREATE TABLE mm.inventario_item (
  inventario_id INT REFERENCES mm.inventario ON DELETE CASCADE,
  material_id INT REFERENCES mm.material,
  quantidade_sistema NUMERIC(14,3) NOT NULL,
  quantidade_contada NUMERIC(14,3) NOT NULL,
  PRIMARY KEY (inventario_id, material_id)
);
-- origem do movimento já cobre movimentação interna via 'INTERNO'

-- 5) PP: MRP e apontamento de chão de fábrica
CREATE TABLE pp.mrp (
  id BIGSERIAL PRIMARY KEY,
  material_id INT NOT NULL REFERENCES mm.material,
  horizonte_semanas INT NOT NULL DEFAULT 12,
  demanda_prevista NUMERIC(14,3) NOT NULL DEFAULT 0,
  demanda_gerada_por_ia NUMERIC(14,3),   -- saída do modelo de previsão (IA/ML)
  gerado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE pp.apontamento_producao (
  id BIGSERIAL PRIMARY KEY,
  ordem_id INT NOT NULL REFERENCES pp.ordem_producao,
  colaborador_id INT REFERENCES rh.colaborador,
  quantidade_produzida NUMERIC(14,3) NOT NULL CHECK (quantidade_produzida > 0),
  quantidade_refugo NUMERIC(14,3) NOT NULL DEFAULT 0,
  apontado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_apont_ordem ON pp.apontamento_producao (ordem_id, apontado_em DESC);

-- 10) QM: plano de amostragem
CREATE TABLE qm.plano_amostragem (
  id SERIAL PRIMARY KEY, material_id INT NOT NULL REFERENCES mm.material,
  nivel_inspecao VARCHAR(10) NOT NULL DEFAULT 'NORMAL',
  tamanho_amostra INT NOT NULL, nai INT NOT NULL,          -- nº máximo de defeitos aceitáveis
  CHECK (nai <= tamanho_amostra)
);

-- 9) GRC: segregação de funções (SoD)
CREATE TABLE grc.sod_regra (
  id SERIAL PRIMARY KEY,
  perfil_a INT NOT NULL REFERENCES sys.perfil,
  perfil_b INT NOT NULL REFERENCES sys.perfil,
  descricao TEXT NOT NULL,
  CHECK (perfil_a <> perfil_b),
  UNIQUE (perfil_a, perfil_b)
);
CREATE TABLE grc.auditoria_interna (
  id SERIAL PRIMARY KEY,
  escopo TEXT NOT NULL, inicio DATE NOT NULL, fim DATE,
  parecer TEXT, conformidade BOOLEAN
);

-- 14) SYS: monitoramento e performance
CREATE TABLE sys.metrica_performance (
  id BIGSERIAL PRIMARY KEY,
  coletado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
  consulta TEXT NOT NULL,
  tempo_ms NUMERIC(12,3), linhas BIGINT, via VARCHAR(12) DEFAULT 'pg_stat_statements'
);
CREATE INDEX ix_metrica_coleta ON sys.metrica_performance (coletado_em DESC);

-- Auditoria nas novas tabelas críticas
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'fi.extrato_bancario','fi.obrigacao_acessoria','fi.imposto_documento',
    'rh.vaga','rh.candidato','mm.inventario','pp.mrp','am.manutencao']
  LOOP
    EXECUTE format('CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON %s
                    FOR EACH ROW EXECUTE FUNCTION sys.fn_auditoria()', t);
  END LOOP;
END $$;

-- Índices de apoio às novas consultas
CREATE INDEX ix_mvcaixa_conta ON fi.movimento_caixa (conta_id, data_mov DESC);
CREATE INDEX ix_mrp_material ON pp.mrp (material_id, gerado_em DESC);

-- Procedure: conciliação automática por valor/data
CREATE OR REPLACE PROCEDURE fi.sp_conciliar_extrato(p_conta INT)
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE fi.extrato_bancario e SET conciliado = TRUE, lancamento_id = l.id
   FROM fi.lancamento l
  WHERE e.conta_id = p_conta AND e.conciliado = FALSE
    AND e.data_mov = l.data_lancamento AND e.valor = l.valor;
END $$;

-- Procedure: cálculo de impostos da NF (ICMS/PIS/COFINS ilustrativos)
CREATE OR REPLACE PROCEDURE fi.sp_calcular_impostos_nota(p_nota INT)
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO fi.imposto_documento (nota_id, tributo_id, base_calculo, valor)
  SELECT n.id, t.id, n.valor,
         CASE t.nome WHEN 'ICMS' THEN ROUND(n.valor*0.18,2)
                     WHEN 'PIS'  THEN ROUND(n.valor*0.0165,2)
                     WHEN 'COFINS' THEN ROUND(n.valor*0.076,2) END
    FROM sd.nota_fiscal n CROSS JOIN fi.tributo t
   WHERE n.id = p_nota AND t.nome IN ('ICMS','PIS','COFINS')
  ON CONFLICT (nota_id, tributo_id) DO NOTHING;
END $$;

-- View BI: tributos por competência (integração fiscal)
CREATE VIEW bi.vw_impostos_periodo AS
SELECT date_trunc('month', n.emissao)::date AS competencia, t.nome AS tributo,
       SUM(i.base_calculo) AS base, SUM(i.valor) AS imposto
  FROM fi.imposto_documento i
  JOIN sd.nota_fiscal n ON n.id = i.nota_id
  JOIN fi.tributo t ON t.id = i.tributo_id
 GROUP BY 1, 2;

-- View BI: produtividade do chão de fábrica
CREATE VIEW bi.vw_produtividade AS
SELECT o.id AS ordem, o.produto_id, o.quantidade AS planejado,
       COALESCE(SUM(a.quantidade_produzida),0) AS produzido,
       COALESCE(SUM(a.quantidade_refugo),0) AS refugo
  FROM pp.ordem_producao o
  LEFT JOIN pp.apontamento_producao a ON a.ordem_id = o.id
 GROUP BY o.id, o.produto_id, o.quantidade;

-- Ajuste de permissões para os novos objetos
GRANT SELECT ON fi.extrato_bancario, fi.obrigacao_acessoria, bi.vw_impostos_periodo,
      bi.vw_produtividade, pp.mrp, pp.apontamento_producao TO erp_diretor;
GRANT SELECT, INSERT, UPDATE ON pp.mrp, pp.apontamento_producao, mm.inventario,
      mm.inventario_item, qm.plano_amostragem TO erp_gerente;
GRANT SELECT, INSERT, UPDATE ON mm.inventario, mm.inventario_item,
      pp.apontamento_producao, qm.plano_amostragem TO erp_supervisor;
GRANT SELECT ON bi.vw_impostos_periodo, bi.vw_produtividade TO erp_analista;

-- Seeds complementares
INSERT INTO fi.tributo (nome, tipo, aliquota) VALUES
 ('ICMS','INDIRETO',18.00),('PIS','INDIRETO',1.65),('COFINS','INDIRETO',7.60),
 ('IRPJ','DIRETO',15.00),('CSLL','DIRETO',9.00);
INSERT INTO rh.beneficio (nome, tipo, custo_mensal) VALUES
 ('Vale Alimentação','ALIMENTACAO',600),('Plano de Saúde','SAUDE',850),('Vale Transporte','TRANSPORTE',220);

INSERT INTO sys.parametro VALUES ('moeda','BRL','Moeda padrão'),('dias_vencimento','30','Prazo padrão');
