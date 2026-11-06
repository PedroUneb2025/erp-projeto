# DW — BI e previsão de demanda

## Modelo e carga

Dimensões: tempo, clientes, produtos e fornecedores. Fatos: vendas, financeiro, estoque e produção. Todos começam vazios.

`sp_carregar_dim_tempo(inicio,fim)` materializa o calendário real solicitado; não inventa vendas. As demais dimensões recebem origem, origem_id e nome reais. Procedures de fatos recebem array JSONB no contrato descrito abaixo. São cargas idempotentes, não extratores completos dos módulos que ainda não existem.

| Procedure | Campos de cada item, além de origem, origem_id e tempo_id |
|---|---|
| `sp_carregar_fato_vendas` | cliente_id, produto_id, quantidade, valor |
| `sp_carregar_fato_financeiro` | categoria, tipo (`entrada`/`saida`), valor |
| `sp_carregar_fato_estoque` | produto_id, fornecedor_id (pode ser NULL), quantidade, valor |
| `sp_carregar_fato_producao` | produto_id, quantidade, perdas |

IDs de dimensões são IDs do DW. Não passe IDs do core como se fossem essas chaves. As constraints impedem fatos sem dimensões e valores inválidos. Não há linha “cliente desconhecido” gerada automaticamente. `origem_id` deve refletir o grão correto; por exemplo, itens distintos não podem usar só a chave do pedido.

## Metabase

1. Abra `http://localhost:3000` e crie sua própria conta administrativa real.
2. Adicione uma conexão PostgreSQL: host `postgres`, porta `5432`, banco `erp`, usuário `erp_bi` e senha da variável `BI_DB_PASSWORD` no seu `.env`.
3. Essa conta lê somente as quatro views analíticas. Não use `erp_migrator` no Metabase.
4. Crie uma pergunta SQL para cada arquivo em `docs/dw/consultas/` e salve em uma coleção “ERP - BI”.
5. Vendas: gráfico por mês de receita e quantidade. Financeiro: saldo por mês. Estoque: tabela de último saldo por produto. Produção: quantidades e perdas por mês.
6. Crie os quatro dashboards e adicione as perguntas. Ajuste formato monetário e ordenação de datas.
7. Sem carga real, mantenha o estado “sem resultados”. Não substitua por números de exemplo.
8. Após integrar as cargas dos colegas, confronte totais com a origem e só então capture evidências.

Os arquivos SQL são entregues; dashboards não foram criados na sua conta porque o Metabase do grupo ainda não existe neste contexto.

## Previsão

Execução após carga real:

```sh
docker compose exec api python -m app.dw.forecast
```

Cada produto precisa de pelo menos 60 dias consecutivos com totais diários completos. A rotina recusa ausência e lacunas: não preenche dias faltantes automaticamente com zero. Se a origem confirmar dia sem venda, a futura carga pode registrar quantidade zero de forma explícita e rastreável.

Os últimos 14 dias são reservados para avaliação temporal (MAE). Depois o modelo RandomForest é reestimado no histórico completo e prevê 14 dias. O resultado não é uma garantia de demanda nem deve gerar compras automaticamente. A adequação do modelo, sazonalidade, feriados e comparação com uma linha de base dependem de dados reais. Não há previsão pré-gerada.

## Pendente

Extratores de `sd`, `fi`, `mm` e `pp`, regras de cancelamento e atualização, agendamento das cargas, linhagem com C e validação dos dashboards. A documentação não confunde procedures prontas com integração pronta.
