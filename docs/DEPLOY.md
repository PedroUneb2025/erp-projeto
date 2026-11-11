# Deploy em produção (grátis, sem servidor local)

Este projeto roda 100% em nuvem no plano gratuito: **Neon** (banco),
**Render** (API Node) e **Vercel** (frontend React). Total: R$ 0.

## Passo 1 — Banco no Neon

1. Crie a conta em https://neon.com e um projeto (ex.: `erp`).
2. Copie a connection string (botão **Connect**).
3. Aplique as migrações pela sua máquina (com psql) ou pelo **SQL Editor**
   do próprio Neon (cole e rode cada arquivo):

   | Ordem | Arquivo |
   |---|---|
   | 1 | `db/migration/V1__erp_schema_base.sql` |
   | 2 | `db/migration/V2__usuarios_roles.sql` |
   | 3 | `db/migration/V3__dados_demo.sql` |

## Passo 2 — API no Render

1. Suba o repositório para o GitHub (ver seção abaixo).
2. Em https://render.com (conta grátis) → **New → Web Service** →
   conecte o repositório.
3. Configure:
   - **Root directory:** `backend`
   - **Build command:** `npm install`
   - **Start command:** `npm start`
   - **Variáveis de ambiente:**
     - `DATABASE_URL` = string do Neon
     - `JWT_SECRET` = qualquer segredo forte
4. Deploy. A URL pública fica `https://seu-projeto.onrender.com`.
   Confira o healthcheck em `/health` e o Swagger em `/api-docs`.

   > Alternativa: o repositório já traz `backend/render.yaml`
   > (Blueprint). Você pode usar **New → Blueprint** apontando o repo e
   > apenas preenchendo o `DATABASE_URL` no painel.

## Passo 3 — Frontend na Vercel

1. Em https://vercel.com (conta grátis) → **Add New → Project** →
   importe o mesmo repositório do GitHub.
2. Configure:
   - **Root directory:** `frontend`
   - **Framework preset:** Vite (detecta sozinho)
   - **Environment variable:** `VITE_API_URL` = `https://seu-projeto.onrender.com`
3. Deploy. Pronto — URL pública `https://seu-projeto.vercel.app`.

Login de demonstração: **admin / senha123**.

## Passo 4 — Deploy contínuo

O workflow `.github/workflows/ci.yml` roda a cada push em `main`:
sobe um PostgreSQL em container, aplica as migrações, roda os testes
de banco (V4) e os testes de API. O `deploy.yml` aciona o hook de
deploy do Render automaticamente — configure o secret
`RENDER_HOOK_URL` (Render → Settings → Deploy Hook) para o pipeline
completo: push → testes → produção.

## Subir o repositório para o GitHub

```bash
cd pasta-do-projeto
git init
git add .
git commit -m "ERP completo: banco, API e frontend"
git branch -M main
git remote add origin https://github.com/SEU-USUARIO/erp-avancado.git
git push -u origin main
```

(Crie o repositório vazio antes em https://github.com/new — sem README,
para não conflitar.)

## Custos e limites (plano grátis)

| Serviço | Limite | Suficiente para |
|---|---|---|
| Neon | 0,5 GB, compute suspenso quando ocioso | dados de demo + uso leve |
| Render | 750 h/mês, "acorda" após 15 min ocioso | demonstração e provas de conceito |
| Vercel | 100 GB de banda/mês | o frontend |

O "acordar" do Render causa ~30 s de atraso na primeira requisição —
normal no plano grátis.
