# Validação desta entrega

## Verificações executadas

| Verificação | Resultado |
|---|---|
| Sintaxe SQL das nove migrações | Analisada sem erros |
| Execução V40 a V48 em banco vazio | Aprovada em PostgreSQL 16.15 isolado, com pgcrypto e pg_stat_statements |
| pytest com PostgreSQL real e API FastAPI | **31 passaram; 1 ignorado** |
| Teste ignorado | Fluxo completo IoT MongoDB → PostgreSQL; não havia MongoDB ativo neste ambiente |
| Python | Compilação e Ruff sem erros |
| React/Vite | Build de produção concluído |
| Tela inicial em navegador | Validada em desktop (1440 px) e celular (390 px), usando a API real e banco sem contrato core |
| Estado sem core | Login bloqueado corretamente; status de banco conectado e integração pendente |
| Interface | Sem erro JavaScript ou rolagem horizontal na tela inicial verificada |
| Compose principal e de testes | Configurações validadas pelo Docker Compose 2.40.3 |
| Diagramas | SVGs inspecionados visualmente |

## Cobertura relevante

- Ausência do core não cria login falso.
- Token JWT assinado, senha incorreta, sessão revogada e usuário inativo.
- Usuário sem permissão recebe 403; concessão/revogação altera o acesso.
- Último administrador protegido contra remoção de vínculo.
- Vínculo de usuário inexistente recusado.
- Configurações auditadas com ator e exclusão lógica.
- Limite de corpo de requisição.
- HMAC rejeita adulteração e assinatura antiga; webhook é idempotente.
- Canal não configurado não finge envio.
- Worker trata sucesso, erro retentável e erro definitivo; limite de cinco tentativas e reprocessamento.
- Cadeia válida, bloqueio de alteração e detecção de conteúdo adulterado.
- Modelo IoT rejeita timestamp sem fuso e valores não finitos.
- Carga DW idempotente, FKs, rollback integral do lote e saldo financeiro.
- Painel sem dados retorna lista vazia.
- Previsão recusa histórico ausente/incompleto e mantém validação temporal.

As respostas HTTP externas são substituídas apenas dentro de testes automatizados, para verificar códigos de erro sem chamar um serviço de terceiros. Nenhum servidor falso, conector de demonstração ou fixture é iniciado pelo Compose normal.

## Não validado nem apresentado como concluído

- `docker compose up` completo com construção de todas as imagens: não havia daemon Docker neste ambiente. Os testes de banco/API foram executados diretamente no PostgreSQL 16 isolado.
- Flyway CLI em execução real: arquivos SQL foram executados diretamente para testar o banco; o workflow e Compose configuram Flyway migrate/validate, mas ainda precisam rodar no ambiente do grupo.
- MongoDB, sensores reais e IoT de ponta a ponta.
- Metabase e criação dos dashboards na instalação do grupo.
- Login contra o cadastro **real** da Pessoa A, pois ele não foi entregue. O contrato de autenticação foi testado somente em fixtures isoladas.
- Navegação visual de todas as telas autenticadas; rotas e permissões tiveram testes de API, e a conferência visual cobriu a tela inicial.
- GitHub Actions remoto, pull request, proteção da main e publicação no Notion.
- Arquivo nativo `.dbs` e exportação no DbSchema.
- Cargas reais dos módulos dos colegas e modelos de previsão treinados em dados de negócio.

## Como reproduzir

Use os comandos de teste do README. Eles criam um projeto Docker separado, `erp-d-test`, e exigem variáveis de teste. O banco deve terminar em `_test` e `ALLOW_TEST_FIXTURES=1` deve estar definido; a suíte recusa executar fixtures fora desse contexto.

O Compose de testes inclui MongoDB, portanto o teste IoT será executado nele. Confira o resultado antes de afirmar que todo o fluxo está aprovado.
