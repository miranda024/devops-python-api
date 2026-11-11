# devops-python-api — Pipeline CI/CD com GitHub Actions, Docker, ECR e EC2

## 1. Descrição da aplicação

API HTTP de tarefas escrita em Python com FastAPI. Ela permite listar, criar e concluir tarefas, e expõe endpoints de saúde (`/health`) e de versão (`/version`), que são usados pelas pipelines para confirmar o deploy.

O objetivo do projeto é demonstrar uma esteira completa de integração e entrega contínua: toda alteração aprovada na branch `main` é testada, empacotada em uma imagem Docker, publicada no Amazon ECR e implantada automaticamente em uma instância Amazon EC2.

| Método | Caminho | Objetivo | Resposta esperada |
|---|---|---|---|
| GET | `/` | Apresentar a API | `200` |
| GET | `/health` | Informar saúde e versão | `200` |
| GET | `/version` | Informar versão e commit implantado | `200` |
| GET | `/tasks` | Listar tarefas | `200` |
| POST | `/tasks` | Criar uma tarefa | `201` |
| PATCH | `/tasks/{id}/done` | Concluir uma tarefa | `200` ou `404` |

Os dados ficam em memória (são perdidos quando o contêiner é recriado). Detalhes do código em [docs/API.md](docs/API.md).

## 2. Tecnologias utilizadas

- **Python 3.13** e **FastAPI** (API) com **Uvicorn** (servidor HTTP)
- **pytest** e **pytest-cov** (testes automatizados e cobertura mínima de 90%)
- **Ruff** (análise estática e formatação)
- **Docker** (containerização)
- **GitHub Actions** (pipelines de CI e CD)
- **Amazon ECR** (registro privado de imagens)
- **Amazon EC2** com Amazon Linux 2023 (hospedagem do contêiner)
- **AWS IAM Role** (`LabRole`, permissão de leitura do ECR pela instância)

## 3. Execução local

Pré-requisitos: Git e Python 3.13.

```bash
git clone https://github.com/miranda024/devops-python-api.git
cd devops-python-api

python3 -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\Activate.ps1
python -m pip install --requirement requirements-dev.txt

uvicorn app.main:app --reload
```

Acesse <http://localhost:8000/docs> (Swagger) ou <http://localhost:8000/health>.

Verificações (as mesmas executadas pelas pipelines):

```bash
ruff check .
ruff format --check .
pytest --cov=app --cov-report=term-missing
```

## 4. Construção e execução da imagem Docker

O `Dockerfile` usa `python:3.13-slim`, instala as dependências de `requirements.txt` durante o build, copia o pacote `app`, executa como usuário sem privilégios e inicia a API com Uvicorn na porta `8000`.

```bash
docker build --tag devops-python-api:local .
docker run --rm --detach --name devops-python-api --publish 8000:8000 devops-python-api:local

curl http://localhost:8000/health
docker ps
docker logs devops-python-api
docker stop devops-python-api
```

Também é possível usar `docker compose up --build`. Leitura detalhada do Dockerfile em [docs/DOCKER.md](docs/DOCKER.md).

## 5. Pipeline de integração contínua (`ci.yml`)

Arquivo: [.github/workflows/ci.yml](.github/workflows/ci.yml)

**Gatilho:** abertura ou atualização de um Pull Request com destino à `main` (também pode ser executada manualmente).

| Job | O que faz |
|---|---|
| `Qualidade e testes` | checkout do código → configura Python 3.13 → instala `requirements-dev.txt` → `ruff check` → `ruff format --check` → `pytest` com cobertura → guarda relatórios (`coverage.xml`, `junit.xml`) como artefato |
| `Build e teste do container` | só roda se o job anterior passar (`needs`) → constrói a imagem → sobe o contêiner → testa `/health` |

O resultado aparece no próprio Pull Request (verde = aprovado, vermelho = falhou). A branch `main` está protegida para exigir que a CI passe antes do merge.

## 6. Pipeline de entrega contínua (`deploy.yml`)

Arquivo: [.github/workflows/deploy.yml](.github/workflows/deploy.yml)

**Gatilho:** `push` na `main`, que acontece quando um Pull Request é mesclado.

| Job | O que faz |
|---|---|
| `Testes automatizados` | executa novamente Ruff e pytest sobre o código da `main` |
| `Build, publicação no ECR e deploy na EC2` | **só roda se os testes passarem** (`needs: tests`) |

Passos do job de deploy:

1. Autentica na AWS com credenciais guardadas em **GitHub Secrets**.
2. Faz login no Amazon ECR.
3. Constrói a imagem e aplica a tag com o SHA do commit (`repo/trabalho:<sha>`).
4. Envia a imagem ao ECR.
5. Conecta na EC2 por **SSH com chave** e executa [scripts/deploy.sh](scripts/deploy.sh), que:
   - autentica o Docker da instância no ECR usando a **IAM Role** da EC2;
   - baixa a imagem do commit;
   - remove o contêiner anterior e inicia o novo (porta `80` → `8000`, `--restart unless-stopped`);
   - verifica se o contêiner está em execução e respondendo em `/health`.
6. Testa a API pelo endereço público da EC2 (`/version`).

### Secrets utilizados (configurados em *Settings → Secrets and variables → Actions*)

| Secret | Conteúdo |
|---|---|
| `AWS_ACCESS_KEY_ID` | chave de acesso temporária do AWS Academy |
| `AWS_SECRET_ACCESS_KEY` | chave secreta temporária do AWS Academy |
| `AWS_SESSION_TOKEN` | token de sessão do AWS Academy |
| `EC2_HOST` | IP ou DNS público da instância |
| `EC2_USER` | usuário SSH (`ec2-user` no Amazon Linux) |
| `EC2_SSH_KEY` | conteúdo da chave privada `.pem` do par de chaves da instância |

Nenhuma credencial é versionada no repositório.

## 7. Arquitetura de implantação

```text
 Desenvolvedor
      │ git push (branch feature/...)
      ▼
 ┌──────────────────────── GitHub ────────────────────────┐
 │ Pull Request → ci.yml (ruff + pytest + teste do contêiner)
 │        │ merge aprovado
 │        ▼
 │ push na main → deploy.yml
 │        ├─ job tests (ruff + pytest)
 │        └─ job deploy ── docker build/push ──────────┐
 └────────────────────────────┬──────────────────────── │ ──┘
                              │ SSH (porta 22)          ▼
                              │               ┌──────────────────┐
                              │               │   Amazon ECR     │
                              ▼               │   repo/trabalho  │
                ┌───────────────────────────┐ │   :<sha-commit>  │
                │ Amazon EC2 (Amazon Linux) │ └────────┬─────────┘
                │ IAM Role: LabRole         │◄─────────┘ docker pull
                │ Docker → contêiner da API │
                │ porta 80 → 8000           │
                └─────────────┬─────────────┘
                              │ HTTP (porta 80)
                              ▼
                          Usuário / navegador
```

Security Group da instância: entrada TCP `22` (SSH, autenticação somente por chave) e TCP `80` (HTTP da API).

## 8. Endereço da API publicada

- API: `http://54.91.109.156/`
- Swagger: `http://54.91.109.156/docs`
- Versão implantada: `http://54.91.109.156/version`

> O IP público da instância do AWS Academy muda quando o laboratório é reiniciado. As evidências 05 e 06 foram capturadas com o IP anterior (54.90.188.167).

## 9. Evidências da execução das pipelines

As capturas de tela estão em [`docs/evidencias/`](docs/evidencias/).

| Evidência | Arquivo |
|---|---|
| CI executada com sucesso no Pull Request | [01-ci-pr.png](docs/evidencias/01-ci-pr.png) |
| Imagens publicadas no ECR com a tag do commit (1.1.0 e 1.0.0) | [02-ecr.png](docs/evidencias/02-ecr.png), [02b-ecr-tag-v1.png](docs/evidencias/02b-ecr-tag-v1.png) |
| Pipeline de deploy executada com sucesso | [03-deploy.png](docs/evidencias/03-deploy.png) |
| Contêiner em execução na EC2 (`docker ps`) | [04-ec2-docker-ps.png](docs/evidencias/04-ec2-docker-ps.png) |
| API acessível pelo navegador — versão 1.0.0 (commit `dc541de`) | [05-api-v1.png](docs/evidencias/05-api-v1.png) |
| API atualizada automaticamente — versão 1.1.0 (commit `7ca1e11`) | [06-api-v2.png](docs/evidencias/06-api-v2.png) |
| Deploy disparado automaticamente pelo merge do PR #3 | [07-deploy-automatico-pr3.png](docs/evidencias/07-deploy-automatico-pr3.png) |
| Pull Request #2 com os commits da implementação | [08-pull-request-2.png](docs/evidencias/08-pull-request-2.png) |
| EC2 com Docker instalado e acesso ao ECR via IAM Role | [09-ec2-docker-iam-role.png](docs/evidencias/09-ec2-docker-iam-role.png) |
| Credenciais armazenadas em GitHub Secrets | [10-github-secrets.png](docs/evidencias/10-github-secrets.png) |
| Proteção da branch `main` (PR e status checks obrigatórios) | [11-protecao-branch-main.png](docs/evidencias/11-protecao-branch-main.png) |
| Instância EC2 criada para hospedar a aplicação | [12-ec2-instancia.png](docs/evidencias/12-ec2-instancia.png) |
| Deploy após reinício do laboratório (novo IP) | [13-deploy-apos-reinicio-lab.png](docs/evidencias/13-deploy-apos-reinicio-lab.png) |
| API respondendo no endereço atual | [14-api-ip-atual.png](docs/evidencias/14-api-ip-atual.png) |

Pull Requests:

- PR #2 — implementação da pipeline CI/CD: <https://github.com/miranda024/devops-python-api/pull/2>
- PR #3 — atualização da API para a versão 1.1.0: <https://github.com/miranda024/devops-python-api/pull/3>

## 10. Como verificar a versão implantada

```bash
curl http://54.91.109.156/version
# {"version":"1.1.0","commit":"<sha completo do commit>"}
```

O campo `commit` deve ser igual ao SHA do último commit da `main` (visível na aba **Actions** e no histórico do GitHub) e à tag da imagem no ECR.

Na instância, também é possível conferir:

```bash
docker ps --filter name=devops-python-api
```

## Limpeza dos recursos

Após a avaliação: encerrar a instância EC2, excluir as imagens e o repositório `repo/trabalho` no ECR e encerrar o laboratório do AWS Academy.
