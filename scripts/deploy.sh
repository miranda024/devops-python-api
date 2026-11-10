#!/usr/bin/env bash
# Executado DENTRO da EC2 pelo workflow deploy.yml (via SSH).
# Uso: deploy.sh <registry> <repositorio> <tag> <regiao>
set -euo pipefail

REGISTRY="$1"
REPOSITORY="$2"
TAG="$3"
AWS_REGION="$4"

IMAGE="$REGISTRY/$REPOSITORY:$TAG"
CONTAINER_NAME="devops-python-api"
HOST_PORT=80

echo "==> Autenticando o Docker da instância no ECR (IAM Role da EC2)"
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

echo "==> Baixando a imagem $REPOSITORY:$TAG"
docker pull "$IMAGE"

echo "==> Substituindo o contêiner anterior"
docker rm --force "$CONTAINER_NAME" 2>/dev/null || true

docker run \
  --detach \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  --publish "$HOST_PORT:8000" \
  --env APP_COMMIT="$TAG" \
  "$IMAGE"

echo "==> Verificando se o contêiner está em execução"
for attempt in $(seq 1 15); do
  if curl --fail --silent "http://127.0.0.1:$HOST_PORT/health"; then
    echo
    docker ps --filter "name=$CONTAINER_NAME"
    docker image prune --force > /dev/null
    exit 0
  fi
  echo "Tentativa $attempt: aguardando a API"
  sleep 2
done

echo "A API não respondeu. Logs do contêiner:"
docker logs "$CONTAINER_NAME"
exit 1
