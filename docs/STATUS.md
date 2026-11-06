# Estado da implementação — Pessoa D

“Implementado” descreve código entregue. Não significa integração externa ou execução na conta do grupo concluída. Consulte `VALIDACAO.md` para o que foi efetivamente testado.

| Requisito | Entrega atual | Falta para concluir no grupo |
|---|---|---|
| Ambiente | Compose, bootstrap seguro, API, frontend, worker, Metabase, MongoDB | Executar no computador do grupo; integrar réplica/backup da B |
| SYS | Perfis, permissões, vínculos, parâmetros, JWT, sessões revogáveis, acessos, auditoria, monitoramento e telas | Contrato real de core.usuarios, FK, administrador real e CRUD compartilhado |
| INTEG | Fila persistente, HTTP POST real configurável, assinatura HMAC, idempotência, retentativas, logs e reprocessamento | URLs, credenciais e formatos reais dos sistemas; adaptadores específicos |
| Webhook | Recebe e armazena evento assinado como `recebido` | Regra de negócio que consome o evento, com o dono do módulo |
| DW | Quatro dimensões, quatro fatos, constraints, índices, procedures de carga e views | Extrair dados dos schemas reais; definir cancelamentos, correções e linhagem com colegas |
| Dashboards | Quatro consultas prontas e passo a passo Metabase | Configurar Metabase real, criar cartões e registrar evidências |
| IA | Treinamento/validação temporal e gravação de previsões | Pelo menos 60 dias completos de vendas reais por produto e avaliação do resultado |
| IoT | Endpoint autenticado, armazenamento bruto MongoDB, agregação PostgreSQL | Sensores reais e integração de ponta a ponta no ambiente do grupo |
| Cadeia de hashes | Registro serializado, bloqueio de mutação e verificação | Vincular a contratos/auditorias reais; ancoragem externa se necessária |
| Modelos | Diagramas fonte e DDL real | Importar banco no DbSchema, revisar e salvar o .dbs oficial do grupo |
| CI/CD | Workflow e testes por módulo | Enviar ao repositório e comprovar execução do GitHub Actions |
| Documentação | READMEs, contratos, roadmap e plano de treinamento | Importar no Notion do grupo e reunir os READMEs dos colegas |
| GitHub | Arquivos prontos e instruções | Criar repositório privado, colaboradores, proteção da main e PR com revisão |

## Decisões para respeitar seu pedido

- Nenhuma carga de exemplo, usuário provisório, gráfico fictício ou simulador de sensor.
- Os conectores simulados pedidos no guia original não foram incluídos, conforme sua orientação posterior de não usar demonstração.
- As procedures do DW são a etapa de **carga**. Não afirmamos que o ETL completo dos colegas está pronto.
- Não criamos `core.usuarios`, roles de cargos ou tabelas dos outros integrantes.
- A cadeia é local, sem consenso distribuído. Não é uma rede blockchain pública.
- Redis, réplica, backup, módulos alheios e envio Teams não fazem parte desta implementação atual da Pessoa D.

## Objetos mínimos por módulo

| Módulo | Trigger | Procedure | Function | Views | Sequence e índices |
|---|---|---|---|---|---|
| SYS | `trg_sessoes_acessos`, auditoria | `sp_revogar_sessoes` | `fn_usuario_tem_permissao` | `vw_usuarios_perfis`, `vw_consultas_lentas`, `vw_acessos_diarios` | Sequences IDENTITY, índices de usuário e acessos |
| INTEG | `trg_eventos_auditoria`, `trg_blocos_imutaveis` | `sp_reprocessar_falhas` | `fn_atraso_retry`, `fn_registrar_bloco`, `fn_verificar_cadeia` | `vw_integracoes_com_erro`, `vw_resumo_integracoes`, `vw_sensores_horarios` | Sequences IDENTITY, fila e chamada |
| DW | Triggers de auditoria das dimensões/fatos | `sp_carregar_dim_*`, `sp_carregar_fato_*` | `fn_mes` | Quatro views de BI | Sequences IDENTITY e índices nas FKs |
