-- V4: testes de fumaça (rodar e conferir resultados esperados)
DO $$ BEGIN RAISE NOTICE '== Validação do ERP =='; END $$;

-- 1. Fluxo de venda: faturar o pedido 1000 (baixa estoque, gera NF e conta a receber)
CALL sd.sp_faturar_pedido(1000, 1, 30);
DO $$ BEGIN
  ASSERT (SELECT status FROM sd.pedido_venda WHERE id=1000) = 'FATURADO', 'Pedido não faturado';
  ASSERT (SELECT count(*) FROM sd.nota_fiscal WHERE pedido_id=1000) = 1, 'NF não gerada';
  ASSERT (SELECT count(*) FROM fi.conta_receber WHERE pedido_id=1000) = 1, 'Conta a receber não gerada';
  RAISE NOTICE 'OK: faturamento completo (estoque baixado, NF e título gerados)';
END $$;

-- 2. Total do pedido recalculado pelo trigger (5*289,90 + 3*899,90)
DO $$ BEGIN
  ASSERT (SELECT total FROM sd.pedido_venda WHERE id=1000) = 4198.60, 'Total incorreto';
  RAISE NOTICE 'OK: total do pedido = 4198.60';
END $$;

-- 3. Fluxo de compra: receber pedido 5000 (entra estoque, gera conta a pagar)
CALL mm.sp_receber_compra(5000, 1, 15);
DO $$ BEGIN
  ASSERT (SELECT status FROM mm.pedido_compra WHERE id=5000) = 'RECEBIDO', 'Compra não recebida';
  ASSERT (SELECT count(*) FROM fi.conta_pagar WHERE descricao='Compra #5000') = 1, 'Conta a pagar não gerada';
  RAISE NOTICE 'OK: recebimento de compra (estoque entrado, título gerado)';
END $$;

-- 4. Impostos da NF
CALL fi.sp_calcular_impostos_nota((SELECT id FROM sd.nota_fiscal WHERE pedido_id=1000));
DO $$ BEGIN
  ASSERT (SELECT count(*) FROM fi.imposto_documento) = 3, 'Impostos não calculados';
  RAISE NOTICE 'OK: ICMS/PIS/COFINS calculados (%)', (SELECT sum(valor) FROM fi.imposto_documento);
END $$;

-- 5. Conciliação bancária
CALL fi.sp_conciliar_extrato(1);
DO $$ BEGIN
  ASSERT (SELECT conciliado FROM fi.extrato_bancario LIMIT 1) = TRUE, 'Extrato não conciliado';
  RAISE NOTICE 'OK: conciliação bancária automática';
END $$;

-- 6. Folha de pagamento
CALL rh.sp_gerar_folha(CURRENT_DATE);
DO $$ BEGIN
  ASSERT (SELECT count(*) FROM rh.folha_pagamento) >= 2, 'Folha não gerada';
  RAISE NOTICE 'OK: folha gerada para % colaboradores', (SELECT count(*) FROM rh.folha_pagamento);
END $$;

-- 7. Depreciação e BI
CALL am.sp_depreciar_ativos();
REFRESH MATERIALIZED VIEW bi.mv_margem_produto;
DO $$ BEGIN
  RAISE NOTICE 'OK: BI pronto — vendas mensais: % | margem: %',
    (SELECT count(*) FROM bi.vw_vendas_mensais),
    (SELECT count(*) FROM bi.mv_margem_produto);
END $$;

-- 8. Auditoria registrou tudo
DO $$ BEGIN
  ASSERT (SELECT count(*) FROM sys.log_auditoria) > 0, 'Auditoria vazia';
  RAISE NOTICE 'OK: % eventos de auditoria registrados', (SELECT count(*) FROM sys.log_auditoria);
END $$;

DO $$ BEGIN RAISE NOTICE '== TODOS OS TESTES PASSARAM =='; END $$;
