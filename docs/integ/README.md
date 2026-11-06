# INTEG — Integrações, IoT e cadeia de hashes

## Fila de saída

`POST /api/v1/integ/eventos` exige `integ.escrever` e recebe canal, chave de idempotência e objeto payload. O canal deve estar configurado de verdade em `CONNECTORS_JSON`; o valor inicial `{}` não configura nenhum serviço.

A configuração é um objeto em que cada chave é o nome do canal, e cada valor contém `url` (HTTPS) e, opcionalmente, `token_env` (nome da variável com token Bearer). A URL não pode ter senha/usuário embutidos e não aceita redirecionamento. Informe apenas destinos autorizados; nomes e URLs não são editáveis pelo cliente da API. Se houver `token_env`, inclua a variável no ambiente do worker no Compose; o Compose não transmite automaticamente variáveis arbitrárias do host.

O worker usa `FOR UPDATE SKIP LOCKED`, timeout de 10 segundos, no máximo cinco tentativas automáticas e atraso exponencial limitado a uma hora. Status não retentáveis, como 400, vão para falha. `POST /eventos/{id}/reprocessar` reinicia o contador para uma intervenção autorizada; o histórico das chamadas permanece.

A resposta de destino não é armazenada para evitar capturar credenciais ou dados desnecessários. Logs registram status HTTP, tipo de erro, duração e número da tentativa. Os payloads enviados ficam no banco e precisam de política de retenção e acesso conforme o conteúdo real.

## Webhook de entrada

Endpoint `/api/v1/integ/webhooks/{canal}`. Cadastre o segredo real por canal em `WEBHOOK_SECRETS_JSON`, sem enviar o `.env` ao Git. Não existe canal padrão.

Cabeçalhos obrigatórios:

- `X-Timestamp`: Unix timestamp em segundos, tolerância de 300 segundos.
- `X-Signature`: `sha256=` seguido do HMAC-SHA256 hexadecimal de `timestamp + "." + corpo_bruto`, usando o segredo do canal.
- `Idempotency-Key`: ID estável do evento, de 1 a 128 caracteres.

Corpo deve ser um objeto JSON, limitado a 256 KiB. Comparação de assinatura usa tempo constante. Repetição da mesma chave e conteúdo retorna o mesmo ID; mesma chave com outro conteúdo retorna 409.

Receber e persistir não executa automaticamente uma regra de venda/pagamento. Eventos ficam em `recebido` até o dono do módulo definir o consumidor. Não marque recebimento como liquidação de pagamento.

## IoT com sensores reais

`POST /api/v1/integ/iot/leituras` usa Bearer JWT com `integ.escrever`. Campos: evento_id UUID, sensor, metrica, unidade, instante ISO 8601 com fuso e valor finito. Instantes futuros são recusados. O MongoDB guarda dados brutos com ID único; repetição divergente retorna 409.

Worker busca leituras ainda não processadas, agrupa por sensor/métrica/unidade/hora UTC e recalcula a janela completa no MongoDB; grava quantidade, média, mínimo e máximo no PostgreSQL via upsert. Só marca as leituras como processadas após o commit. Repetição após falha não soma duas vezes, e leituras atrasadas atualizam a janela anterior.

Não há simulador, cron de geração fictícia ou dados pré-carregados. A autenticação de dispositivos de longa duração, identidade individual de cada sensor e rotação automática de tokens são evolução futura; hoje o cliente real precisa renovar o JWT de 30 minutos.

## Cadeia de hashes

`POST /blocos` registra dados; `GET /blocos/verificacao` verifica a cadeia. A função serializa inclusões com advisory lock e calcula SHA-256 do hash anterior concatenado à representação canônica JSONB do conteúdo.

UPDATE, DELETE e TRUNCATE são bloqueados por trigger; conta da aplicação também não recebe UPDATE nos blocos. O teste de adulteração é executado pelo dono do banco somente no banco de testes. Não há seed de contrato fictício.

Limites: é um encadeamento local de dados, não uma blockchain distribuída. Um DBA pode desabilitar triggers e reescrever toda a cadeia ou remover seu final; sem âncora externa isso não é detectável. O hash protege `dados` e `anterior`; metadados como timestamp e created_by não estão no cálculo. Para prova externa, definir ancoragem e assinatura em evolução futura.
