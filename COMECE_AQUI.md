# Sua parte do ERP — comece aqui

Este pacote contém o trabalho da Pessoa D que pode ser preparado agora, sem inventar dados dos colegas. Não é a entrega final integrada do grupo.

## 1. O que você recebeu

- Banco dos módulos SYS, INTEG e DW, nas migrações V40 a V48.
- API e telas administrativas, com login por JWT preparado para o cadastro real do core.
- Permissões por perfil, logs de login/logout, auditoria e monitoramento.
- Webhook real com assinatura, fila de envio HTTP e reprocessamento.
- Estrutura de BI, procedures de carga e consultas para quatro dashboards.
- Previsão de demanda que só executa com histórico suficiente.
- Recepção de sensores reais no MongoDB e resumo horário no PostgreSQL.
- Cadeia local de hashes com bloqueio de alteração e verificação.
- Testes, pipeline GitHub Actions, documentação, modelos, roadmap e treinamento.

Não há usuário, senha, cliente, venda ou sensor de demonstração. O catálogo de perfis e permissões é configuração real do sistema. Os dados sintéticos encontrados em `backend/tests/` são exclusivamente fixtures de testes automatizados, protegidas para só rodar em banco cujo nome termina em `_test`; não entram no ambiente normal.

## 2. Preparar o computador Windows

1. Instale Docker Desktop, Git e VS Code, caso ainda não tenha.
2. Abra o Docker Desktop e aguarde ele indicar que está em execução. Use contêineres Linux.
3. Extraia **todo** o ZIP em uma pasta, por exemplo `Documentos/erp-pessoa-d`.
4. Abra essa pasta no VS Code. Clique em Terminal > Novo Terminal.
5. Confira que o terminal está dentro da pasta que contém `docker-compose.yml`.
6. Execute:

```powershell
powershell -ExecutionPolicy Bypass -File .\Iniciar.ps1
```

A opção vale só para esse processo do PowerShell. O script cria senhas aleatórias locais, preserva um `.env` existente e inicia os serviços. A primeira execução baixa imagens e instala dependências; pode levar vários minutos.

7. Confira os serviços:

```powershell
docker compose ps
docker compose logs --tail=80 api flyway
```

O Flyway terminar com código 0 é normal: ele executa as migrações e encerra. Os demais serviços permanecem ativos.

8. Abra:

- Painel: http://localhost:5173
- Documentação da API: http://localhost:8000/docs
- Saúde da API: http://localhost:8000/health
- Metabase: http://localhost:3000

**A tela inicialmente informa que aguarda o cadastro compartilhado. Isso é esperado. Não existe conta provisória para entrar.** O banco e os serviços podem iniciar antes do core; autenticação e telas protegidas só podem ser usados após a integração real.

## 3. O que combinar com seus colegas

**Pessoa A:** pedir as migrações reais do `core`, especialmente `core.usuarios`, e os nomes/tipos das colunas de ID, e-mail, senha com hash, ativo e exclusão lógica. Não crie outra tabela de usuários. Veja `docs/CONTRATOS.md` e `scripts/gerar_contrato_core.py`.

**Pessoa C:** confirmar as roles e GRANTs do banco. Os perfis com os mesmos nomes em SYS são permissões da aplicação; eles não substituem as roles PostgreSQL. Pedir os contratos de estoque, produção e auditoria compartilhada.

**Pessoa B:** pedir as tabelas e regras das vendas, inclusive cancelamentos e devoluções. Coordenar a réplica e backup dela com seu Compose, que é um arquivo de dono único.

## 4. O que você pode mostrar agora

- As pastas, as nove migrações e os modelos em `docs/modelagem/`.
- O ambiente iniciado, o status de dependências e a documentação `/docs` da API.
- Os testes automatizados e o relatório `docs/VALIDACAO.md`.
- O código real de segurança, fila, webhook, carga, previsão e IoT.
- A lista honesta de pendências em `docs/STATUS.md`.

Você ainda não pode mostrar login real, gráficos com vendas reais ou sensores recebendo leituras se as respectivas fontes não existirem. Não apresente telas vazias como evidência de integração concluída.

## 5. Enviar ao GitHub

Crie um repositório **privado** e vazio no GitHub. Na pasta deste projeto:

```powershell
git init
git branch -M main
git add .
git commit -m "feat(d): prepara administracao integracoes e BI"
```

Depois execute os comandos `git remote add origin ...` e `git push -u origin main` mostrados pelo GitHub para o seu repositório. Não copie uma URL de outro projeto.

Adicione os três colegas em Settings > Collaborators. Em Settings > Rules > Rulesets (ou Branch protection), configure a branch main para exigir pull request com uma aprovação e os checks do CI. A disponibilidade dessas regras em repositórios privados depende do plano do GitHub; confira na sua conta e combine a alternativa com o grupo se necessário.

Depois do primeiro envio, trabalhe em branches por tarefa. Não altere migração já compartilhada; crie outra. A V49 está reservada para a integração real do core. Combine nova faixa com A se precisar de mais migrações.

## 6. Desligar sem apagar dados

```powershell
docker compose down
```

Para voltar: `docker compose up -d`. **Não use `down -v` no projeto normal**: ele apaga os volumes e os dados. O uso de `down -v` no CI se restringe ao projeto descartável de testes.

Se algo falhar, envie a saída de `docker compose ps` e dos logs. Não envie `.env`, senhas ou tokens.
