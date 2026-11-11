-- V2: cria usuários de aplicação (com login) herdando os perfis RBAC
-- As senhas abaixo são EXEMPLO — troque em produção (com pgcrypto/ gerenciador de segredos).
CREATE ROLE app_admin LOGIN PASSWORD 'SUBSTITUA_SENHA_ADMIN';
CREATE ROLE app_diretor LOGIN PASSWORD 'SUBSTITUA_SENHA_DIRETOR';
CREATE ROLE app_gerente LOGIN PASSWORD 'SUBSTITUA_SENHA_GERENTE';
CREATE ROLE app_supervisor LOGIN PASSWORD 'SUBSTITUA_SENHA_SUPERVISOR';
CREATE ROLE app_analista LOGIN PASSWORD 'SUBSTITUA_SENHA_ANALISTA';

GRANT erp_dba    TO app_admin;     -- CEO/DBA: acesso total
GRANT erp_ceo    TO app_admin;
GRANT erp_diretor    TO app_diretor;
GRANT erp_gerente    TO app_gerente;
GRANT erp_supervisor TO app_supervisor;
GRANT erp_analista   TO app_analista;

-- Usuários de aplicação não criam objetos
ALTER ROLE app_diretor    NOCREATEDB NOCREATEROLE;
ALTER ROLE app_gerente    NOCREATEDB NOCREATEROLE;
ALTER ROLE app_supervisor NOCREATEDB NOCREATEROLE;
ALTER ROLE app_analista   NOCREATEDB NOCREATEROLE;
