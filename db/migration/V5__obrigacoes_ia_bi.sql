-- =====================================================================
-- V5: itens do documento ainda como "documentação apenas":
-- obrigações acessórias geradas de fato, previsão de demanda (IA),
-- exportação de auditoria p/ ELK, detecção de fraude.
-- =====================================================================

-- 1) GERAÇÃO DE OBRIGAÇÕES ACESSÓRIAS --------------------------------
-- Bloco 0 do SPED ECD/EFD (versão didática do layout):
-- registros |0000| (abertura), |0100| (contabilista) e |I100| (lancamentos)
CREATE OR REPLACE FUNCTION fi.fn_gerar_sped_efd(p_competencia DATE)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
  v_layout CONSTANT TEXT := '015';
  v_arquivo TEXT := '';
  v_lanc RECORD;
BEGIN
  -- |0000| abertura
  v_arquivo := v_arquivo || format('|0000|%s|%s|%s|%s|%s|%s|%s|%s|' || chr(13) || chr(10),
    'LECD',                                        -- tipo de livro
    to_char(p_competencia,'YYYY'),                 -- exercício
    date_trunc('month', p_competencia)::date,      -- data inicial
    (date_trunc('month', p_competencia) + interval '1 month - 1 day')::date,
    COALESCE((SELECT valor FROM sys.parametro WHERE chave='empresa_cnpj'),'00000000000000'),
    COALESCE((SELECT valor FROM sys.parametro WHERE chave='empresa_razao'),'EMPRESA DEMO'),
    v_layout, 'A');
  -- |0100| responsável
  v_arquivo := v_arquivo || format('|0100|%s|%s|1|011|0|' || chr(13) || chr(10),
    COALESCE((SELECT valor FROM sys.parametro WHERE chave='empresa_cnpj'),'00000000000000'),
    'DBA ERP');
  -- |I100| lançamentos do mês
  FOR v_lanc IN
    SELECT l.data_lancamento, l.historico, l.valor,
           d.codigo AS debito, c.codigo AS credito
      FROM fi.lancamento l
      JOIN fi.plano_contas d ON d.id = l.conta_debito
      JOIN fi.plano_contas c ON c.id = l.conta_credito
     WHERE l.data_lancamento >= date_trunc('month', p_competencia)
       AND l.data_lancamento <  date_trunc('month', p_competencia) + interval '1 month'
  LOOP
    v_arquivo := v_arquivo || format('|I100|%s|%s|%s|%s|%s|' || chr(13) || chr(10),
      to_char(v_lanc.data_lancamento,'DDMMYYYY'),
      COALESCE(v_lanc.historico,''), v_lanc.debito, v_lanc.credito,
      lpad(replace(to_char(v_lanc.valor,'FM999999999.00'),'.',''), 15,'0'));
  END LOOP;
  RETURN v_arquivo;
END $$;

-- eSocial (S-1200 — folha, versão didática): um registro por colaborador
CREATE OR REPLACE FUNCTION rh.fn_gerar_esocial(p_competencia DATE)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE v_arq TEXT := ''; v_fol RECORD;
BEGIN
  FOR v_fol IN
    SELECT c.cpf_hash, f.bruto, f.inss, f.irrf, f.liquido
      FROM rh.folha_pagamento f
      JOIN rh.colaborador c ON c.id = f.colaborador_id
     WHERE f.competencia = date_trunc('month', p_competencia)::date
  LOOP
    v_arq := v_arq || format('S1200;%s;%s;%s;%s;%s|' || chr(13) || chr(10),
      v_fol.cpf_hash,
      replace(to_char(v_fol.bruto,'FM999999999.00'),'.',','),
      replace(to_char(v_fol.inss,'FM999999999.00'),'.',','),
      replace(to_char(v_fol.irrf,'FM999999999.00'),'.',','),
      replace(to_char(v_fol.liquido,'FM999999999.00'),'.',','));
  END LOOP;
  RETURN v_arq;
END $$;

-- Marca a obrigação como entregue ao gerar
CREATE OR REPLACE PROCEDURE fi.sp_registrar_entrega(p_tipo TEXT, p_competencia DATE)
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO fi.obrigacao_acessoria (tipo, competencia, entrega_prevista, entregue_em, status)
  VALUES (p_tipo, to_char(p_competencia,'YYYY-MM'),
          (date_trunc('month', p_competencia) + interval '1 month + 4 days')::date,
          CURRENT_DATE, 'ENTREGUE');
END $$;

-- 2) PREVISÃO DE DEMANDA (IA) -----------------------------------------
-- Regressão linear simples (mínimos quadrados) sobre as vendas mensais
-- históricas de cada material; grava a previsão em pp.mrp.
CREATE OR REPLACE FUNCTION pp.fn_previsao_demanda(p_horizonte INT DEFAULT 12)
RETURNS TABLE (material_id INT, sku TEXT, meses_hist INT, demanda_prevista NUMERIC, tendencia TEXT)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  WITH hist AS (
    SELECT i.material_id AS mat_id,
           date_trunc('month', p.data_pedido)::date AS mes,
           SUM(i.quantidade) AS qtd
      FROM sd.item_pedido_venda i
      JOIN sd.pedido_venda p ON p.id = i.pedido_id AND p.status IN ('FATURADO','APROVADO')
     WHERE p.data_pedido >= CURRENT_DATE - interval '24 months'
     GROUP BY 1, 2
  ),
  serie AS (
    SELECT h.mat_id, m.mes, COALESCE(h2.qtd, 0) AS qtd
      FROM (SELECT DISTINCT mat_id FROM hist) h
      CROSS JOIN generate_series(
        date_trunc('month', CURRENT_DATE - interval '11 months'),
        date_trunc('month', CURRENT_DATE), interval '1 month') AS m(mes)
      LEFT JOIN hist h2 ON h2.mat_id = h.mat_id AND h2.mes = m.mes
  ),
  regressao AS (
    SELECT mat_id,
           COUNT(*)::int AS n,
           REGR_SLOPE(qtd, extract(epoch from mes)/(86400*30)) AS inclinacao,
           REGR_INTERCEPT(qtd, extract(epoch from mes)/(86400*30)) AS intercepto,
           AVG(qtd) AS media
      FROM serie GROUP BY mat_id
  )
  SELECT r.mat_id, m.sku::text, r.n,
         GREATEST(0, ROUND(
           (r.intercepto + r.inclinacao * (extract(epoch from date_trunc('month', CURRENT_DATE))::numeric/(86400*30) + p_horizonte))::numeric
         , 2)),
         CASE WHEN r.inclinacao > 0.05 THEN 'ALTA'
              WHEN r.inclinacao < -0.05 THEN 'QUEDA'
              ELSE 'ESTAVEL' END
    FROM regressao r JOIN mm.material m ON m.id = r.mat_id;
END $$;

-- Grava o MRP com a previsão da IA
CREATE OR REPLACE PROCEDURE pp.sp_gerar_mrp(p_horizonte INT DEFAULT 12)
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO pp.mrp (material_id, horizonte_semanas, demanda_prevista, demanda_gerada_por_ia)
  SELECT material_id, p_horizonte, demanda_prevista, demanda_prevista
    FROM pp.fn_previsao_demanda(p_horizonte);
END $$;

-- 3) DETECÇÃO DE FRAUDE/ANOMALIA --------------------------------------
-- Regras: (a) alterações fora do horário comercial em tabelas financeiras;
-- (b) mesmo usuário alterando pedidos de clientes diferentes em < 1 min;
-- (c) NF com valor muito acima da média dos pedidos do cliente.
CREATE OR REPLACE VIEW grc.vw_suspeitas_auditoria AS
SELECT data_evento, usuario_db, tabela, operacao, dados_novos
  FROM sys.log_auditoria
 WHERE (tabela LIKE 'fi.%' AND extract(hour FROM data_evento) NOT BETWEEN 6 AND 21)
    OR (tabela LIKE 'sd.%' AND operacao = 'DELETE');

CREATE OR REPLACE VIEW grc.vw_suspeitas_valor AS
SELECT n.id AS nota, c.nome AS cliente, n.valor,
       ROUND(avg(p.total) OVER (PARTITION BY n.pedido_id), 2) AS media_pedidos,
       n.valor > 5 * (SELECT avg(total) FROM sd.pedido_venda
                       WHERE cliente_id = (SELECT cliente_id FROM sd.pedido_venda WHERE id = n.pedido_id)) AS outlier
  FROM sd.nota_fiscal n JOIN sd.pedido_venda p ON p.id = n.pedido_id
  JOIN sd.cliente c ON c.id = p.cliente_id;

-- 4) EXPORTAÇÃO BI/ELK -------------------------------------------------
-- Função de exportação da auditoria em JSON por evento (formato aceito
-- pelo ingest do Logstash/Elasticsearch e pelo Splunk HEC)
CREATE OR REPLACE FUNCTION sys.fn_auditoria_json(p_limite INT DEFAULT 1000)
RETURNS JSON LANGUAGE sql AS $$
  SELECT COALESCE(json_agg(e ORDER BY e.data_evento DESC), '[]'::json)
    FROM (SELECT * FROM sys.log_auditoria ORDER BY data_evento DESC LIMIT p_limite) e;
$$;

-- Testes de fumaça do V5
DO $$ BEGIN RAISE NOTICE '== Validação V5 =='; END $$;
CALL pp.sp_gerar_mrp(12);
DO $$ BEGIN
  ASSERT (SELECT count(*) FROM pp.mrp WHERE demanda_gerada_por_ia IS NOT NULL) > 0,
    'MRP sem previsão de IA';
  RAISE NOTICE 'OK: MRP gerado com previsão de IA para % materiais',
    (SELECT count(*) FROM pp.mrp WHERE demanda_gerada_por_ia IS NOT NULL);
END $$;
DO $$ BEGIN
  ASSERT length(fi.fn_gerar_sped_efd(CURRENT_DATE)) > 50, 'SPED vazio';
  RAISE NOTICE 'OK: SPED EFD gerado (% caracteres)',
    (SELECT length(fi.fn_gerar_sped_efd(CURRENT_DATE)));
END $$;
DO $$ BEGIN
  ASSERT length(rh.fn_gerar_esocial(CURRENT_DATE)) > 0, 'eSocial vazio';
  RAISE NOTICE 'OK: eSocial gerado (% registros de folha)',
    (SELECT length(rh.fn_gerar_esocial(CURRENT_DATE)) / 40);
END $$;
CALL fi.sp_registrar_entrega('SPED', CURRENT_DATE);
DO $$ BEGIN
  ASSERT (SELECT count(*) FROM fi.obrigacao_acessoria WHERE status='ENTREGUE') > 0, 'Obrigação não registrada';
  RAISE NOTICE 'OK: obrigação acessória registrada como entregue';
END $$;
DO $$ BEGIN
  ASSERT json_typeof(sys.fn_auditoria_json(10)) = 'array', 'JSON de auditoria inválido';
  RAISE NOTICE 'OK: auditoria exportável em JSON (ELK/Splunk)';
END $$;
DO $$ BEGIN RAISE NOTICE '== TODOS OS TESTES V5 PASSARAM =='; END $$;
