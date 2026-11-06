# ERP — Implementação da Pessoa D

Comece por [COMECE_AQUI.md](COMECE_AQUI.md). Este pacote é código de preparação e implementação dos módulos SYS, INTEG e DW, sem serviços falsos, sensores simulados ou dados de demonstração. Dependências externas são explicitamente pendentes.

## Executar

Windows: abra Docker Desktop e rode `powershell -ExecutionPolicy Bypass -File .\Iniciar.ps1`.

Linux/macOS com Python 3 e Docker Compose:

```sh
python3 scripts/configurar.py
docker compose up -d --build
```

Painel `http://localhost:5173`, API `http://localhost:8000/docs`, Metabase `http://localhost:3000`.
As portas ficam vinculadas a `127.0.0.1`. Este ambiente é local, não um deploy público de produção.

## Estado e responsabilidades

- [Estado por requisito](docs/STATUS.md)
- [Contratos com A, B e C](docs/CONTRATOS.md)
- [Administração](docs/sys/README.md)
- [Integrações e IoT](docs/integ/README.md)
- [BI e previsão](docs/dw/README.md)
- [Modelagem](docs/modelagem/README.md)
- [Validação executada](docs/VALIDACAO.md)
- [Roadmap](docs/ROADMAP.md)
- [Treinamento](docs/TREINAMENTO.md)
- [Índice para importar no Notion](docs/INDICE_NOTION.md)

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `db/migrations` | V40 a V48, objetos reais PostgreSQL 16 |
| `db/init` | Contas técnicas do ambiente, sem cargos do grupo |
| `db/seeds` | Explicação da ausência de dados de demonstração |
| `backend/app/sys` | JWT, sessão revogável, RBAC, parâmetros |
| `backend/app/integracoes` | Webhook, fila, HTTP, IoT |
| `backend/app/dw` | Consultas e previsão de demanda |
| `backend/tests` | Testes em banco descartável |
| `frontend/src` | React, Vite e Tailwind |
| `docs` | Documentação de implementação e pendências |
| `scripts` | Configuração local, contrato core e administração inicial |

## Testes em ambiente descartável

PowerShell:

```powershell
$env:TEST_DB_PASSWORD = [guid]::NewGuid().ToString('N')
$env:TEST_JWT_SECRET = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
docker compose -f docker-compose.test.yml run --build --rm tests pytest -q
docker compose -f docker-compose.test.yml run --rm flyway validate
docker compose -f docker-compose.test.yml down -v
```

O Compose de testes tem outro nome, outros volumes e não publica portas. Fixtures de identidade são criadas em `test_support`, nunca em `core`. Elas são exclusivamente testes e não um módulo substituto entregue ao grupo.

## CI/CD

`.github/workflows/ci.yml` usa jobs independentes por módulo, PostgreSQL 16, MongoDB, Flyway e pytest; também compila o frontend. O job de imutabilidade compara migrações do PR com a branch base, porque executar apenas Flyway em banco vazio não detecta edição de uma migração antiga. `validate` verifica o histórico aplicado naquele banco.

Não há deploy automático: falta um destino real autorizado. Não há repositório, PR ou execução remota do Actions criado por este pacote.

## Integração de migrações

O pacote isolado começa em V40. Em um banco de grupo novo, reúna as migrações de A/B/C e rode tudo em ordem, de V1 em diante. Não coloque V1–V39 depois de V48 em um banco compartilhado já migrado sem planejar com A: Flyway não aplica essas versões fora de ordem por padrão. Nunca rode `repair`, `clean` ou apague volumes para ocultar divergências de histórico.

As migrações ainda são uma entrega local nova. Depois de enviadas ao grupo, passam a ser imutáveis. Nenhum arquivo de outro integrante foi alterado.
