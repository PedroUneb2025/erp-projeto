-- V2: cadastros compartilhados (schema core). Somente a Pessoa A altera.
-- core.usuarios segue o contrato de docs/CONTRATOS.md: id, email, senha_hash, ativo, deleted_at.
-- Perfis/cargos dos usuarios ficam em sys.usuarios_perfis (Pessoa D), nao aqui.

CREATE OR REPLACE FUNCTION core.fn_set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TABLE core.usuarios (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nome        text        NOT NULL,
  email       text        NOT NULL,
  senha_hash  text        NOT NULL
              CHECK (senha_hash ~ '^\$2[abxy]\$[0-9]{2}\$.{53}$'),  -- bcrypt: crypt(senha, gen_salt('bf'))
  ativo       boolean     NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  created_by  bigint REFERENCES core.usuarios(id),
  deleted_at  timestamptz
);
-- login unico ignorando maiusculas
CREATE UNIQUE INDEX ux_usuarios_email_lower ON core.usuarios (lower(email));

CREATE TABLE core.colaboradores (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  usuario_id    bigint REFERENCES core.usuarios(id),
  nome          text        NOT NULL,
  cpf           varchar(11) NOT NULL UNIQUE,
  email         text,
  telefone      text,
  data_admissao date,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  created_by    bigint REFERENCES core.usuarios(id),
  deleted_at    timestamptz
);

CREATE TABLE core.clientes (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tipo_pessoa char(1)     NOT NULL CHECK (tipo_pessoa IN ('F','J')),
  nome        text        NOT NULL,
  documento   varchar(14) NOT NULL UNIQUE,   -- CPF ou CNPJ, so digitos
  email       text,
  telefone    text,
  endereco    text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  created_by  bigint REFERENCES core.usuarios(id),
  deleted_at  timestamptz
);

CREATE TABLE core.fornecedores (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  razao_social text        NOT NULL,
  cnpj         varchar(14) NOT NULL UNIQUE,
  email        text,
  telefone     text,
  endereco     text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  created_by   bigint REFERENCES core.usuarios(id),
  deleted_at   timestamptz
);

CREATE INDEX ix_colaboradores_usuario_id  ON core.colaboradores(usuario_id) WHERE deleted_at IS NULL;
CREATE INDEX ix_clientes_nome             ON core.clientes(nome)            WHERE deleted_at IS NULL;
CREATE INDEX ix_fornecedores_razao_social ON core.fornecedores(razao_social) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_usuarios_update      BEFORE UPDATE ON core.usuarios      FOR EACH ROW EXECUTE FUNCTION core.fn_set_updated_at();
CREATE TRIGGER trg_colaboradores_update BEFORE UPDATE ON core.colaboradores FOR EACH ROW EXECUTE FUNCTION core.fn_set_updated_at();
CREATE TRIGGER trg_clientes_update      BEFORE UPDATE ON core.clientes      FOR EACH ROW EXECUTE FUNCTION core.fn_set_updated_at();
CREATE TRIGGER trg_fornecedores_update  BEFORE UPDATE ON core.fornecedores  FOR EACH ROW EXECUTE FUNCTION core.fn_set_updated_at();
