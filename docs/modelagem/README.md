# Modelagem da Pessoa D

Os diagramas nesta pasta mostram as entidades e relacionamentos implementados. As migrações são a definição completa e executável das colunas, constraints e índices.

- `sys.mmd`: modelo lógico de segurança e configuração, sem duplicar `core.usuarios`.
- `integ.mmd`: eventos, tentativas e cadeia; resumos IoT são independentes dos eventos de integração.
- `dw.mmd`: constelação de quatro fatos compartilhando dimensões.
- As versões SVG permitem abrir os desenhos diretamente no navegador.

## Gerar o arquivo oficial do DbSchema

1. Suba o PostgreSQL pelo Compose.
2. No DbSchema, crie conexão PostgreSQL para localhost:5432, database erp, usuário erp_migrator e a senha POSTGRES_PASSWORD do .env.
3. Faça reverse engineering dos schemas sys, integ e dw.
4. Separe os layouts SYS, INTEG e DW. Ajuste posição dos objetos; confira as FKs com este pacote.
5. Salve o projeto .dbs e exporte PDF/PNG para a entrega final.
6. Depois de integrar a V49, atualize o modelo para incluir os vínculos com core.usuarios.

Não entregamos um .dbs fabricado ou uma exportação que não foi feita no DbSchema. A ferramenta deve importar o schema real. No desenho SYS a ligação ao core aparece como pendente porque sua FK ainda não existe.

## Decisões de modelagem

Tabelas em plural, snake_case, PK IDENTITY bigint, timestamps e created_by, exclusão lógica nas tabelas de negócio. Há vínculos lógicos de ator ao core ainda sem FK até conhecermos o cadastro real. Tabelas operacionais e de auditoria não são expostas para exclusão pela API.

Vendas: um item de venda. Financeiro: um movimento. Estoque: fotografia diária consolidada por produto. Produção: um apontamento por produto. As dimensões usam SCD tipo 1; o modelo é uma constelação, pois há quatro estrelas com dimensões compartilhadas.
