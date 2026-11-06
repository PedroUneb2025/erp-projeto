# Roadmap de longo prazo

Prazos relativos à integração do grupo; não são datas de entrega inventadas.

| Etapa | Prioridades | Critério de conclusão |
|---|---|---|
| Integração inicial | Core real, FK, roles A/C, usuário administrador, DDL dos fatos | Login e permissões testados com usuários reais; nenhuma referência órfã |
| Primeiro ciclo de dados | Extratores, cancelamentos, linhagem, reconciliação, dashboards | Totais de origem e DW conciliados e evidências reproduzíveis |
| Segundo ciclo | Adaptadores de serviços reais, consumidor de webhooks, alertas, dead-letter operacional | Falhas/repetições controladas em ambiente autorizado |
| Terceiro ciclo | Identidade de dispositivos IoT, rotação de tokens, retenção MongoDB e logs | Sensores reais autenticados e retenção aprovada |
| Evolução analítica | Comparar previsão com baseline, sazonalidade, intervalos e monitoramento de erro | Modelo só promovido se superar baseline em validação temporal |
| Segurança e operação | MFA, TLS, segredos gerenciados, backup/restauração com B, auditoria central com C | Teste de restauração e revisão de acessos aprovados |

## Revisão trimestral de performance

1. Registrar volume, p95 de latência, filas pendentes, falhas de integração, tempo das cargas e tamanho dos índices.
2. Revisar `pg_stat_statements`; usar EXPLAIN (ANALYZE, BUFFERS) em consultas selecionadas num ambiente controlado.
3. Verificar índices com B e C, crescimento da auditoria, retenção e necessidade de particionamento.
4. Reavaliar dependências, privilégios, vulnerabilidades, políticas de backup e RPO/RTO.
5. Documentar comparação antes/depois, decisão, responsável e prazo. Toda mudança de schema entra por nova migração e PR revisado.

## Melhorias deliberadamente futuras

Paginação completa (hoje listas têm limites explícitos), refresh token, bloqueio de login distribuído, testes de carga, carga incremental com watermark, SCD tipo 2, ancoragem externa da cadeia, métricas observáveis e deploy para um destino definido. Não descrever essas melhorias como implementadas.
