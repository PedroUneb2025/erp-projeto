-- V1: schemas por modulo e roles de cargo (Pessoa A; GRANTs por cargo ficam com a Pessoa C na faixa V30+)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS core;   -- cadastros compartilhados
CREATE SCHEMA IF NOT EXISTS audit;  -- auditoria (tabela generica fica com a Pessoa C)
CREATE SCHEMA IF NOT EXISTS fi;     -- financeiro
CREATE SCHEMA IF NOT EXISTS fisc;   -- integracao contabil e fiscal
CREATE SCHEMA IF NOT EXISTS am;     -- gestao de ativos
CREATE SCHEMA IF NOT EXISTS grc;    -- governanca e compliance
CREATE SCHEMA IF NOT EXISTS rh;
CREATE SCHEMA IF NOT EXISTS sd;
CREATE SCHEMA IF NOT EXISTS sm;
CREATE SCHEMA IF NOT EXISTS mm;
CREATE SCHEMA IF NOT EXISTS pp;
CREATE SCHEMA IF NOT EXISTS qm;
CREATE SCHEMA IF NOT EXISTS ps;
CREATE SCHEMA IF NOT EXISTS sys;
CREATE SCHEMA IF NOT EXISTS integ;
CREATE SCHEMA IF NOT EXISTS dw;

-- Roles de cargo do PostgreSQL (sem login). Nao sao as contas tecnicas erp_app, erp_bi e metabase.
DO $$
DECLARE r text;
BEGIN
  FOREACH r IN ARRAY ARRAY['role_ceo','role_dba','role_diretor','role_gerente','role_supervisor','role_operador']
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
      EXECUTE format('CREATE ROLE %I NOLOGIN', r);
    END IF;
  END LOOP;
END $$;

GRANT USAGE ON SCHEMA core, audit, fi, fisc, am, grc, rh, sd, sm, mm, pp, qm, ps, sys, integ, dw
  TO role_ceo, role_dba, role_diretor, role_gerente, role_supervisor, role_operador;

-- CEO e DBA: acesso total a tudo que for criado depois pelo usuario das migracoes
ALTER DEFAULT PRIVILEGES GRANT ALL ON TABLES    TO role_ceo, role_dba;
ALTER DEFAULT PRIVILEGES GRANT ALL ON SEQUENCES TO role_ceo, role_dba;
ALTER DEFAULT PRIVILEGES GRANT ALL ON FUNCTIONS TO role_ceo, role_dba;
