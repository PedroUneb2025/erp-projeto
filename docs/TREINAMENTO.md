# Plano curto de treinamento

Duração sugerida: 60 minutos, após integrar o cadastro real. Responsável pela condução: Pessoa D; A/C apoiam identidade e segurança.

| Tempo | Atividade | Verificação |
|---|---|---|
| 0–10 min | Subir o ambiente e localizar status, API e logs | Cada participante identifica uma dependência pendente |
| 10–25 min | Login, logout, vinculação de perfis e permissões | Usuário autorizado acessa; usuário sem permissão recebe 403 |
| 25–35 min | Parametrizações e auditoria | Alteração real controlada deixa registro com ator |
| 35–45 min | Estados de integração, erro e reprocessamento | Participante diferencia recebido, pendente, falha e concluído |
| 45–55 min | Consultar BI e limites da previsão | Participante entende origem do indicador e ausência de dados |
| 55–60 min | Segurança e dúvidas | Ninguém compartilha .env/token; participante sabe revogar sessão |

Usar ambiente de treinamento autorizado e dados reais minimizados ou testes descartáveis, conforme a política do grupo. Este pacote não inclui base de demonstração.

## Segurança essencial

- Não enviar .env, senhas, hashes ou tokens a GitHub, Teams ou prints.
- Conceder o mínimo de permissões. `sys.escrever` é privilégio de administração de acessos.
- Não publicar as portas locais na internet sem projeto de segurança e deploy.
- Não editar migrações aplicadas; corrigir com migração nova.
- Não apagar volumes para “resolver” um erro sem backup e aprovação de quem é dono dos dados.
- Antes de reprocessar, confirmar idempotência do destino e evitar duplicar operação financeira.

Registrar data, participantes, dúvidas e confirmação das atividades no Notion do grupo. Não há lista de presença ou treinamento concluído pré-preenchidos.
