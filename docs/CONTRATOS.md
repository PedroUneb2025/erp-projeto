# Contratos e limites com os colegas

## Usuários — Pessoa A

Não existe cadastro paralelo em SYS. O único ponto de leitura da identidade é uma view a ser criada depois de conhecer o DDL real: `sys.vw_identidades_core`.

| Coluna de saída da view | Tipo esperado | Significado |
|---|---|---|
| `id` | bigint | ID estável e único do core |
| `email` | text | Login único, sem duplicidade ignorando maiúsculas |
| `senha_hash` | text | Hash bcrypt compatível com PostgreSQL `crypt`/`gen_salt('bf')` |
| `ativo` | boolean | Se o usuário pode autenticar |
| `deleted_at` | timestamptz | Exclusão lógica; NULL para usuário não excluído |

Esses nomes são a interface que a Pessoa D precisa receber, não uma afirmação sobre as colunas que A já criou. Não use uma view vazia ou fictícia para habilitar o sistema.

Depois que A entregar as colunas, `scripts/gerar_contrato_core.py` gera V49 com nomes informados por você e inclui a FK dos vínculos, sessões e logs. A ferramenta só escreve a migração; não descobre nem valida sozinha os nomes/tipos do core. Você confere o DDL com A, revisa e aplica via Flyway. Execute com Python 3 e os argumentos obrigatórios --id, --email, --senha-hash, --ativo, --deleted-at e --saida db/migrations/V49__sys_contrato_core.sql. Cada argumento de coluna recebe o nome REAL informado por A. Não há mapeamento de exemplo predefinido. A view deve ter SELECT para a conta técnica `erp_app`; nenhuma API retorna o hash.

O cadastro, alteração, troca de senha e bloqueio de usuários serão conectados ao serviço de A. Hoje a tela lista usuários reais e administra seus perfis; **não há CRUD completo do cadastro compartilhado**. Mudança de senha deve chamar `sys.sp_revogar_sessoes(id)` na mesma transação ou por um fluxo confiável. Antes da criação da FK, a API valida a existência no contrato; acesso SQL direto da conta técnica deve permanecer restrito.

## Perfis da aplicação versus roles — Pessoa C

Os seis nomes exigidos estão em `sys.perfis`; CEO/DBA têm todas as permissões da aplicação. Os demais começam sem permissões, até a matriz ser acordada. `erp_app`, `erp_bi` e `metabase` são contas técnicas distintas, não cargos.

A/C precisam criar as roles PostgreSQL e seus GRANTs na faixa delas. Este pacote não as inventa nem usa `SET ROLE` com um nome fornecido pelo cliente. O acesso administrativo total ao ERP do grupo depende de cada módulo usar o mesmo mecanismo de autorização; hoje o bypass CEO/DBA está implementado nos módulos D.

A auditoria própria de D em `sys.auditorias` registra antes/depois e ator. Quando C fornecer `audit.log_auditoria` e sua trigger genérica, combinar adaptação por migração nova; não criar outra tabela no schema `audit` por conta própria.

## Dados analíticos — Pessoas A, B e C

| Responsável | Fonte real a confirmar | Grão do fato de destino |
|---|---|---|
| B | Vendas e itens faturados, cliente, produto, data, quantidades, valores | Um item de venda; `origem_id` deve identificar venda + item |
| A | Entradas e saídas financeiras efetivadas | Um movimento financeiro; evitar misturar previsto e realizado |
| C | Estoque consolidado por produto e data | Uma fotografia diária por produto, total da empresa |
| C | Produção realizada e perdas por produto/data | Uma produção apontada por produto |
| A/C | Clientes, fornecedores, produtos reais | Uma chave da fonte em cada dimensão |

Chave natural no DW: `(origem, origem_id)`. A chave substituta `id` é gerada por IDENTITY. Dimensões usam SCD tipo 1 (nome atualizado); não preservam todas as mudanças históricas. A data é ligada a `dim_tempo`.

As procedures aceitam IDs **das dimensões do DW**, não IDs de origem. O futuro extrator precisa procurar `(origem,origem_id)` para obter o ID correto antes de carregar os fatos. Lotes são atômicos e podem ser repetidos com a mesma chave sem duplicar registros.

Definir antes de integrar: fuso do dia de negócio, impostos/descontos, devoluções, cancelamentos, exclusões da origem, correções retroativas, SLA da carga e consentimento para dados pessoais. As procedures atualizam registros recebidos; **a ausência em um lote não significa exclusão**. Cancelamentos exigem uma etapa explícita de marcação `deleted_at` no DW. Evitar apagar fatos silenciosamente.

Não há conexão automática às tabelas `sd`, `fi`, `mm` ou `pp` enquanto seus DDLs e regras não forem entregues. Registrar a linhagem em conjunto com C: origem, coluna, transformação, destino, periodicidade, responsável.

## Serviços externos

Para cada conector, solicitar URL HTTPS, autenticação, contrato do payload, idempotência, códigos de erro, limites e ambiente autorizado. O transportador genérico envia JSON por POST e trata 2xx como sucesso, 408/425/429/5xx e falhas de rede como retentáveis. Um banco que exija OAuth, certificado, assinatura própria ou confirmação de negócio precisa de adaptador específico, ainda pendente.

Entrega é pelo menos uma vez: se o processo cair depois da resposta do serviço e antes de confirmar no banco, o evento pode ser enviado novamente. O destino precisa respeitar `Idempotency-Key`. Não há garantia de exatamente uma vez entre dois sistemas sem protocolo adicional.
