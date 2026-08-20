# Entendendo o Dockerfile

## Fluxo completo

```text
código + requirements.txt + Dockerfile
                  │
                  ▼ docker build
                imagem
                  │
                  ▼ docker run
               container
                  │
                  ▼ -p 8000:8000
             API acessível no host
```

## 1. Imagem-base

```dockerfile
FROM python:3.13-slim
```

A imagem já contém Python e pip. A variante `slim` reduz pacotes do sistema, sem adotar as diferenças de biblioteca C da variante Alpine.

## 2. Variáveis de ambiente

```dockerfile
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
```

- evita arquivos `.pyc` dentro do container;
- envia logs imediatamente para a saída padrão, facilitando `docker logs`.

## 3. Diretório de trabalho

```dockerfile
WORKDIR /app
```

Os próximos comandos usam `/app` como diretório atual.

## 4. Dependências antes do código

```dockerfile
COPY requirements.txt .
RUN pip install --no-cache-dir --requirement requirements.txt
```

Copiar o arquivo de dependências antes do código melhora o cache. Se apenas `app/main.py` mudar, a camada de instalação pode ser reutilizada.

`--no-cache-dir` evita guardar o cache de download do pip na imagem final.

## 5. Código da aplicação

```dockerfile
COPY app ./app
```

Somente a aplicação entra na imagem. Testes e documentação são usados no repositório e no pipeline, mas não são necessários em execução.

## 6. Usuário sem privilégios

```dockerfile
RUN useradd --create-home --uid 10001 appuser
USER appuser
```

O processo da API não precisa executar como root. O UID explícito também torna a identidade mais previsível.

## 7. Porta e health check

```dockerfile
EXPOSE 8000
```

`EXPOSE` documenta a porta interna; não publica a porta no host. A publicação ocorre com `-p 8000:8000`.

```dockerfile
HEALTHCHECK ... CMD python -c "... /health"
```

O Docker chama o endpoint dentro do próprio container. Consulte o estado com:

```bash
docker inspect --format '{{json .State.Health}}' devops-python-api
```

## 8. Processo principal

```dockerfile
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

- `CMD` define o processo padrão;
- `0.0.0.0` permite receber conexões pela interface de rede do container;
- a forma JSON evita criar um shell intermediário.

## Comandos para a demonstração

### Construir

```bash
docker build --tag devops-python-api:v1 .
docker image ls devops-python-api
```

O ponto final é o contexto de build.

### Executar

```bash
docker run --detach \
  --name devops-python-api \
  --publish 8000:8000 \
  devops-python-api:v1
```

No PowerShell, escreva o comando em uma linha ou troque `\` pelo acento grave.

### Observar

```bash
docker ps
docker logs devops-python-api
curl http://localhost:8000/health
```

### Encerrar e remover

```bash
docker stop devops-python-api
docker rm devops-python-api
```

Ou use `--rm` no `docker run` para remover automaticamente após a parada.

## Docker Compose

```bash
docker compose up --build
docker compose ps
docker compose logs api
docker compose down
```

O `compose.yaml` registra nome do serviço, contexto de build, nome da imagem e mapeamento de portas.

## Diagnóstico orientado por evidências

| Sintoma | Primeira evidência | Causa provável |
|---|---|---|
| Build falha no pip | saída de `docker build` | versão ou rede |
| Container encerra | `docker ps -a` e logs | processo principal falhou |
| Container roda, mas curl falha | `docker port`, logs e host de escuta | porta ou bind incorreto |
| Estado unhealthy | saída do health check no inspect | endpoint não responde |

## Falha intencional

Troque `--host 0.0.0.0` por `--host 127.0.0.1`, gere uma tag `erro` e execute:

```bash
docker build -t devops-python-api:erro .
docker run --rm -p 8000:8000 --name devops-python-api devops-python-api:erro
```

O log informa que o Uvicorn iniciou, mas a porta publicada não alcança o loopback interno. Restaure `0.0.0.0`, reconstrua como `v2` e valide novamente.

## Referências oficiais

- <https://docs.docker.com/language/python/>
- <https://docs.docker.com/reference/dockerfile/>
- <https://docs.docker.com/engine/containers/run/>
