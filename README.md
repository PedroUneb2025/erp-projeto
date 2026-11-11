# ERP Avançado — Projeto Final de Banco de Dados Avançado

Sistema ERP completo em três camadas, conforme o documento do projeto:

| Camada | Tecnologia | Pasta |
|---|---|---|
| **Data Layer** (Unidade 1) | PostgreSQL (Neon), schema modular, triggers, procedures, views, RBAC, auditoria particionada | [`db/`](db/) |
| **Backend** (Unidade 2) | API REST Node.js/Express, JWT, RBAC por perfil, módulos desacoplados | [`backend/`](backend/) |
| **Frontend** (Unidade 3) | React (Vite), dashboards e telas de operação | [`frontend/`](frontend/) |

## Módulos implementados
FI (financeiro + conciliação + fiscal), RH (folha, benefícios, recrutamento),
MM (estoque, compras, inventário), SD/CRM (pedidos, funil, contratos),
PP (BOM, ordens, MRP, apontamento), PS (projetos), SM (ordens de serviço
com SLA), QM (inspeções, não conformidades, amostragem), AM (ativos e
depreciação), GRC (riscos, LGPD, segregação de funções), BI (views +
materializada), SYS (usuários, perfis, auditoria, métricas),
API/IoT/Blockchain (integração, leitura de sensores, hash de contratos).

## Demonstração online (sem instalar nada)
- API: https://erp-avancado.onrender.com (Swagger em `/api-docs`)
- Frontend: publicado no Vercel a partir deste repositório (ver `docs/DEPLOY.md`)

> Deploy gratuito em Render (API) + Neon (banco) + Vercel (frontend).
> Instruções completas em [`docs/DEPLOY.md`](docs/DEPLOY.md).

## Rodando localmente (5 comandos)

```bash
# 1. Banco — crie um projeto grátis em https://neon.com e copie a connection string
#    Aplique as migrações:
psql "$CONNECTION_STRING" -f db/migration/V1__erp_schema_base.sql
psql "$CONNECTION_STRING" -f db/migration/V2__usuarios_roles.sql
psql "$CONNECTION_STRING" -f db/migration/V3__dados_demo.sql

# 2. Backend
cd backend && npm install
DATABASE_URL="sua-string-do-neon" JWT_SECRET="troque" npm run dev

# 3. Frontend (novo terminal)
cd frontend && npm install && npm run dev
```

Login de demonstração: `admin` / `senha123` (perfil DBA/CEO).

## Estrutura

```
db/migration/      SQL versionado (padrão Flyway): schema, roles, dados demo, testes
backend/           API Express — um router por módulo, auth JWT, RBAC
frontend/          SPA React — login, dashboard, cadastros e operações
docs/              Documentação do projeto, deploy, arquitetura
.github/workflows  CI: testes de API contra PostgreSQL real em container
```

## Recursos de banco (Unidade 1)
- 15 schemas por módulo, ~70 tabelas, 3FN
- Triggers: auditoria genérica JSONB, atualização de estoque, recálculo de
  total, bloqueio de pedido faturado
- Procedures: faturamento, recebimento, folha, depreciação, baixa,
  conciliação bancária, impostos por NF
- Views: vendas mensais, estoque crítico, fluxo de caixa, inadimplência,
  SLA, impostos, produtividade, margem (materializada)
- RBAC com roles PostgreSQL (DBA/CEO/Diretor/Gerente/Supervisor/Analista)
- Particionamento de auditoria por RANGE anual, índices parciais/GIN/JSONB
- Segurança: bcrypt para senhas, pgp_sym_encrypt para CPF

## CI/CD
GitHub Actions sobe um PostgreSQL real, aplica as migrações, roda os
testes de API (mocha) e publica automaticamente no Render em `main`.

## Recursos avançados (V5)
- SPED EFD e eSocial gerados a partir dos dados reais (`fi.fn_gerar_sped_efd`, `rh.fn_gerar_esocial`)
- Previsão de demanda com IA (regressão) gravada no MRP (`pp.fn_previsao_demanda`)
- Detecção de fraude (views de suspeitas no GRC)
- Auditoria exportável em JSON para ELK/Splunk e CSV de BI para Power BI
- Tudo exposto na API em `/api/adv/*` (ver Swagger)

## Requisitos e rastreabilidade
Ver matriz em [`docs/documentacao_erp.md`](docs/documentacao_erp.md) (RF01–RF07, RNF01–RNF02).

## Licença
MIT
