-- V2: cria usuários de aplicação (com login) herdando os perfis RBAC
-- As senhas abaixo são EXEMPLO — troque em produção (com pgcrypto/ gerenciador de segredos).
CREATE ROLE app_admin LOGIN PASSWORD 'TroqueEstaSenha1!';
CREATE ROLE app_diretor LOGIN PASSWORD 'TroqueEstaSenha2!';
CREATE ROLE app_gerente LOGIN PASSWORD 'TroqueEstaSenha3!';
CREATE ROLE app_supervisor LOGIN PASSWORD 'TroqueEstaSenha4!';
CREATE ROLE app_analista LOGIN PASSWORD 'TroqueEstaSenha5!';

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
