CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE SCHEMA IF NOT EXISTS sys;
CREATE SCHEMA IF NOT EXISTS integ;
CREATE SCHEMA IF NOT EXISTS dw;
CREATE TABLE sys.perfis (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 created_by bigint, deleted_at timestamptz,
 nome text NOT NULL UNIQUE CHECK(nome IN ('role_ceo','role_dba','role_diretor','role_gerente','role_supervisor','role_operador'))
);
CREATE TABLE sys.permissoes (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 created_by bigint, deleted_at timestamptz,
 codigo text NOT NULL UNIQUE, descricao text NOT NULL
);
CREATE TABLE sys.perfis_permissoes (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 created_by bigint, deleted_at timestamptz,
 perfil_id bigint NOT NULL REFERENCES sys.perfis(id), permissao_id bigint NOT NULL REFERENCES sys.permissoes(id), UNIQUE(perfil_id,permissao_id)
);
CREATE TABLE sys.usuarios_perfis (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 created_by bigint, deleted_at timestamptz,
 usuario_id bigint NOT NULL CHECK(usuario_id>0), perfil_id bigint NOT NULL REFERENCES sys.perfis(id), UNIQUE(usuario_id,perfil_id)
);
CREATE TABLE sys.parametrizacoes (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 created_by bigint, deleted_at timestamptz,
 chave text NOT NULL UNIQUE, valor jsonb NOT NULL, descricao text NOT NULL DEFAULT ''
);
CREATE TABLE sys.sessoes (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 created_by bigint, deleted_at timestamptz,
 usuario_id bigint NOT NULL, jti uuid NOT NULL UNIQUE, expira_em timestamptz NOT NULL, revogada_em timestamptz
);
CREATE TABLE sys.log_acessos (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 created_by bigint, deleted_at timestamptz,
 usuario_id bigint NOT NULL, evento text NOT NULL CHECK(evento IN ('login','logout')), sessao_id bigint NOT NULL REFERENCES sys.sessoes(id)
);
CREATE TABLE sys.auditorias (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 created_by bigint, deleted_at timestamptz,
 tabela text NOT NULL, operacao text NOT NULL, registro_id bigint, antes jsonb, depois jsonb
);

CREATE INDEX ix_usuarios_perfis_usuario_id ON sys.usuarios_perfis(usuario_id) WHERE deleted_at IS NULL;
CREATE INDEX ix_sessoes_jti ON sys.sessoes(jti) WHERE revogada_em IS NULL;
CREATE INDEX ix_log_acessos_created_at ON sys.log_acessos(created_at);
CREATE INDEX ix_auditorias_created_at ON sys.auditorias(created_at);
INSERT INTO sys.perfis(nome) VALUES ('role_ceo'),('role_dba'),('role_diretor'),('role_gerente'),('role_supervisor'),('role_operador');
INSERT INTO sys.permissoes(codigo,descricao) VALUES
 ('sys.ler','Consultar administracao'),('sys.escrever','Gerenciar administracao'),
 ('integ.ler','Consultar integracoes'),('integ.escrever','Enviar e reprocessar eventos'),
 ('dw.ler','Consultar BI'),('dw.escrever','Executar cargas e previsoes');
COMMENT ON COLUMN sys.usuarios_perfis.usuario_id IS 'Referencia logica a core.usuarios.id. FK pendente da publicacao do core pela Pessoa A. API exige identidade real no contrato.';
