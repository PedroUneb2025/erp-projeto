-- Contas tecnicas criadas pelo bootstrap do ambiente, nao sao os cargos de A/C.
DO $$ BEGIN
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='erp_app') THEN
 RAISE EXCEPTION 'Crie a conta tecnica erp_app com db/init/01-roles.sh antes das migracoes'; END IF;
END $$;
REVOKE ALL ON SCHEMA sys,integ,dw FROM PUBLIC;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA sys,integ,dw FROM PUBLIC;
REVOKE EXECUTE ON ALL PROCEDURES IN SCHEMA sys,integ,dw FROM PUBLIC;
GRANT USAGE ON SCHEMA sys,integ,dw TO erp_app;
GRANT SELECT,INSERT,UPDATE ON ALL TABLES IN SCHEMA sys,integ,dw TO erp_app;
GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA sys,integ,dw TO erp_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA sys,integ,dw TO erp_app;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA sys,integ,dw TO erp_app;
REVOKE UPDATE ON sys.auditorias,sys.log_acessos,integ.log_chamadas,integ.blocos FROM erp_app;
-- Metabase usa somente views analiticas; nao acessa usuarios, senhas ou payloads.
DO $$ BEGIN
 IF EXISTS(SELECT FROM pg_roles WHERE rolname='erp_bi') THEN
 GRANT USAGE ON SCHEMA dw TO erp_bi;
 GRANT SELECT ON dw.vw_vendas_por_mes,dw.vw_financeiro_por_mes,dw.vw_estoque_atual,dw.vw_producao_por_mes TO erp_bi;
 END IF;
END $$;
