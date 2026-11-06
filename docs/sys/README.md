# SYS — Administração

## Disponível

Perfis, permissões, vínculos de usuários reais a perfis, parametrizações JSON, sessão com JWT e revogação, logs de login/logout e monitoramento. Os tokens duram 30 minutos, têm issuer/audience fixos e ficam apenas em memória na interface. Recarregar a página pede novo login. Logout revoga a sessão no banco.

Não existe senha padrão. Login ausente retorna 401; acesso sem permissão retorna 403; antes do contrato core, login retorna 503 com instrução clara. Usuário desativado ou sessão revogada perde acesso imediatamente, pois cada requisição consulta a identidade real e a sessão.

O contrato espera bcrypt (`pgcrypto`) por exigência do guia C. Verifique com C a política de senha, o custo bcrypt e o limite de 72 bytes. Não transforme hashes existentes em texto puro. A interface não cadastra nem altera senhas do core.

## Administração inicial

Depois de aplicar a integração V49 e de A criar um usuário real, copie o script para o contêiner e execute informando o ID **real**:

```sh
docker compose cp scripts/primeiro_admin.py api:/tmp/primeiro_admin.py
docker compose exec api python /tmp/primeiro_admin.py ID_REAL
```

Substitua `ID_REAL` por um número existente. O script recusa ausência do core, ID inexistente/inativo e execução se já existe administrador. Não cria contas nem senhas. Depois entre na interface e conceda os demais perfis pelo fluxo normal.

## Rotas

Prefixo `/api/v1/sys`. Endpoints completos e esquemas em `/docs`.

| Grupo | Operações |
|---|---|
| Autenticação | POST login, POST logout, GET me |
| Identidades | GET usuarios (cadastro pertence a A) |
| Perfis | GET perfis, GET permissoes, GET perfis-permissoes |
| Vínculos | PUT usuarios-perfis, DELETE usuarios/{id}/perfis/{id} |
| Autorizações | PUT perfis-permissoes, DELETE perfis/{id}/permissoes/{id} |
| Configurações | GET/PUT parametros, DELETE parametros/{chave} |
| Operação | GET acessos, GET monitoramento |

`sys.escrever` permite administrar autorizações e deve ser concedida apenas a quem pode elevar privilégios. A API impede remover o último vínculo de administrador ativo. Não armazene segredos em parametrizações: use variáveis de ambiente.

## Auditoria e performance

Triggers gravam a tabela, operação, ID, antes/depois e ator em `sys.auditorias`. Datas de atualização são mantidas por triggers. `created_by` é lógico até integrar os IDs do core; registros automáticos podem ser NULL (ator de sistema).

`sys.vw_consultas_lentas` mostra identificador e estatísticas, sem expor o texto de consultas potencialmente sensíveis. PostgreSQL inicia com `shared_preload_libraries=pg_stat_statements`. Retenção dos logs depende da política que o grupo aprovar; nenhum dado é apagado automaticamente.

## Limites atuais

Autenticação contra o core real e CRUD compartilhado ainda dependem de A. Roles e permissões PostgreSQL dos cargos dependem de C. Em uso público, adicionar TLS, MFA, política de senha, bloqueio distribuído de tentativas, gestão de segredos e revisão de dependências. A limitação de login no Nginx vale para o painel; a porta local 8000 existe para desenvolvimento e não deve ser publicada externamente.
