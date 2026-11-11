# Como colocar o ERP num banco real (Neon, plano grátis)

Tempo total: ~15 minutos. Ao final, o banco estará criado, populado com
dados de demonstração, validado por testes e acessível de qualquer
aplicação (psql, DBeaver, Node, Python etc.).

## Passo 1 — Criar a conta e o projeto no Neon (5 min)

1. Acesse https://neon.com e clique em **Sign up** (GitHub, Google ou e-mail).
2. Após entrar, o Neon já cria um projeto padrão. Clique nele (ou crie um
   novo chamado `erp`).
3. Na tela do projeto, abra **Dashboard → Connection string**. Você verá
   algo assim:

   ```
   postgresql://neondb_owner:AbCdEf123456@ep-cool-name-123456.us-east-2.aws.neon.tech/neondb?sslmode=require
   ```

   Guarde essa string: é a "CONNECTION_STRING" usada abaixo. Ela contém
   usuário, senha, host e nome do banco. No plano grátis você tem 0,5 GB
   de armazenamento — mais que suficiente para o ERP com dados de demo.

> Nota: no Neon o usuário do banco (`neondb_owner`) é superusuário do seu
> projeto, então as extensões `pgcrypto` e `pg_trgm` e o particionamento
> funcionam sem nenhuma configuração extra.

## Passo 2 — Instalar o psql no Windows (se ainda não tiver)

Baixe e instale o **psql** sozinho (não precisa instalar o servidor):

1. Acesse https://www.enterprisedb.com/downloads/postgres-postgresql-downloads
   e baixe o instalador do PostgreSQL 16.
2. Durante a instalação, você pode desmarcar o "PostgreSQL Server" e
   deixar apenas **Command Line Tools**.
3. Abra o **PowerShell** e teste:

   ```powershell
   & "C:\Program Files\PostgreSQL\16\bin\psql.exe" --version
   ```

   Se aparecer a versão, está pronto.

## Passo 3 — Aplicar o schema e os dados (3 comandos)

No PowerShell, dentro da pasta onde você extraiu o zip:

```powershell
# troque CONNECTION_STRING pela string copiada no passo 1 (use aspas!)

# 1) Schema completo do ERP (tabelas, triggers, procedures, views, RBAC)
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" "CONNECTION_STRING" -f sql/V1__erp_schema_base.sql

# 2) Usuários de aplicação (troque as senhas em V2 antes de rodar)
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" "CONNECTION_STRING" -f sql/V2__usuarios_roles.sql

# 3) Dados de demonstração
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" "CONNECTION_STRING" -f sql/V3__dados_demo.sql

# 4) Validação (deve terminar com "TODOS OS TESTES PASSARAM")
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" "CONNECTION_STRING" -f sql/V4__validacao.sql
```

Saída esperada no passo 4:

```
NOTICE:  == Validação do ERP ==
NOTICE:  OK: faturamento completo (estoque baixado, NF e título gerados)
NOTICE:  OK: total do pedido = 4198.60
NOTICE:  OK: recebimento de compra (estoque entrado, título gerado)
NOTICE:  OK: ICMS/PIS/COFINS calculados
NOTICE:  OK: conciliação bancária automática
NOTICE:  OK: folha gerada para 2 colaboradores
NOTICE:  OK: BI pronto — ...
NOTICE:  OK: N eventos de auditoria registrados
NOTICE:  == TODOS OS TESTES PASSARAM ==
```

## Passo 4 — Usar o banco

Conecte com a mesma connection string usando DBeaver, pgAdmin ou seu
código. Exemplos:

**Consultar as views de BI:**

```sql
SELECT * FROM bi.vw_vendas_mensais;
SELECT * FROM bi.vw_estoque_critico;
SELECT * FROM bi.vw_fluxo_caixa;
SELECT * FROM bi.vw_impostos_periodo;
```

**Fluxo de venda completo (uma linha):**

```sql
CALL sd.sp_faturar_pedido(1000, 1, 30);
```

**Ver a auditoria:**

```sql
SELECT data_evento, usuario_db, tabela, operacao
FROM sys.log_auditoria ORDER BY data_evento DESC LIMIT 20;
```

**Conectar do seu código (exemplos):**

Node.js (`npm i pg`):

```js
const { Client } = require('pg');
const client = new Client({ connectionString: 'CONNECTION_STRING' });
await client.connect();
const r = await client.query('SELECT * FROM bi.vw_vendas_mensais');
console.log(r.rows);
```

Python (`pip install psycopg[binary]`):

```python
import psycopg
with psycopg.connect("CONNECTION_STRING") as conn:
    for row in conn.execute("SELECT * FROM bi.vw_estoque_critico"):
        print(row)
```

## Passo 5 — Boas práticas para continuar

- **Segredos:** nunca deixe a connection string em código-fonte; use
  variável de ambiente (`DATABASE_URL`).
- **Senhas dos roles:** troque as senhas exemplo do V2 antes de qualquer
  uso compartilhado.
- **Backup:** o Neon mantém histórico (PITR) por 7 dias no plano grátis;
  use `pg_dump` para cópias próprias.
- **Versionamento:** os arquivos V1–V4 seguem o padrão Flyway — se
  adotar o Flyway, coloque-os em `db/migration` e rode
  `flyway migrate` sem mudanças.

## Estrutura do kit

| Arquivo | O que faz |
|---|---|
| `sql/V1__erp_schema_base.sql` | Schema completo do ERP (idêntico ao corrigido) |
| `sql/V2__usuarios_roles.sql` | Usuários de login com RBAC (trocar senhas) |
| `sql/V3__dados_demo.sql` | Dados de demonstração |
| `sql/V4__validacao.sql` | Testes de fumaça do fluxo completo |
| `LEIA-ME.md` | Este guia |
