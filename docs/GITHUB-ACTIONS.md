# Entendendo o GitHub Actions

O workflow está em `.github/workflows/ci.yml`. O GitHub lê automaticamente arquivos YAML desse diretório.

## 1. Nome e gatilhos

```yaml
name: CI Python

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:
```

- `name` define como o workflow aparece na aba Actions.
- `push` executa após commits enviados à `main`.
- `pull_request` verifica a mudança antes do merge.
- `workflow_dispatch` cria o botão para execução manual.

## 2. Permissão mínima

```yaml
permissions:
  contents: read
```

O token automático do workflow recebe somente leitura do repositório. O pipeline não precisa alterar código nem publicar pacotes.

## 3. Concorrência

```yaml
concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Se vários commits forem enviados rapidamente à mesma branch, uma execução antiga é cancelada. A turma pode observar a diferença entre “falhou” e “foi cancelada”.

## 4. Primeiro job: qualidade e testes

```yaml
quality-and-tests:
  runs-on: ubuntu-latest
```

Um job recebe um runner limpo. Nada do ambiente do estudante está disponível, exceto o que o workflow obtém ou instala.

### Checkout

```yaml
- uses: actions/checkout@v6
```

Essa action copia o commit para o diretório de trabalho do runner. Sem ela, os steps seguintes não encontrariam `app`, `tests` ou `requirements-dev.txt`.

### Setup do Python

```yaml
- uses: actions/setup-python@v6
  with:
    python-version-file: .python-version
    cache: pip
    cache-dependency-path: requirements-dev.txt
```

- lê a versão `3.13` de `.python-version`;
- adiciona o interpretador ao `PATH`;
- tenta restaurar o cache do pip;
- associa a chave do cache ao arquivo de dependências.

O cache acelera downloads, mas não substitui a instalação. Por isso o próximo step continua necessário.

### Instalação

```yaml
- run: python -m pip install --requirement requirements-dev.txt
```

`requirements-dev.txt` inclui as dependências de execução e acrescenta pytest, cobertura, cliente HTTP e Ruff.

### Gates de qualidade

```yaml
- run: ruff check .
- run: ruff format --check .
```

O primeiro comando procura problemas de código. O segundo verifica a formatação sem modificar arquivos. Qualquer retorno diferente de zero interrompe o job.

### Testes e cobertura

```yaml
- run: |
    pytest \
      --cov=app \
      --cov-report=term-missing \
      --cov-report=xml:coverage.xml \
      --junitxml=reports/junit.xml
```

O `pytest` executa os testes. O projeto exige pelo menos 90% de cobertura em `pyproject.toml`. São produzidos dois arquivos:

- `coverage.xml`: cobertura no formato Cobertura;
- `reports/junit.xml`: resultados no formato JUnit.

### Artefatos

```yaml
- if: always()
  uses: actions/upload-artifact@v7
```

`if: always()` faz o step tentar guardar os relatórios mesmo quando os testes falham. Na página da execução, procure a seção **Artifacts**.

## 5. Segundo job: container

```yaml
container-smoke-test:
  needs: quality-and-tests
```

`needs` cria uma dependência: o container só é construído se o primeiro job for aprovado. Isso evita gastar tempo com uma versão que já falhou em testes ou qualidade.

### Build imutável por commit

```yaml
docker build --tag devops-python-api:${{ github.sha }} .
```

`${{ github.sha }}` é uma expressão do Actions. Ela usa o hash do commit como tag, ligando a imagem ao código verificado.

### Smoke test

O container inicia em segundo plano e o workflow tenta chamar `/health`. O laço aceita o pequeno intervalo entre criar o container e a aplicação ficar pronta. Se nenhuma tentativa receber uma resposta HTTP bem-sucedida, o step falha.

### Diagnóstico e limpeza

Os steps finais usam `if: always()`:

- `docker logs` preserva a evidência do processo;
- `docker rm --force` libera o runner mesmo após uma falha.

## 6. Como diagnosticar uma falha

Leia a execução de fora para dentro:

1. Qual job falhou?
2. Qual foi o primeiro step vermelho?
3. Qual comando foi executado?
4. A mensagem aponta código, teste, dependência, formatação, build ou execução?
5. A correção deve ocorrer no código ou no pipeline?

Não comece pelo último step: steps com `if: always()` podem aparecer depois da causa original.

## 7. Experimentos para sala

1. Faça um push bem-sucedido e identifique as evidências.
2. Introduza `import os` sem uso e observe o Ruff falhar.
3. Corrija, faça novo push e compare as execuções.
4. Quebre a resposta de `/health` e observe o pytest.
5. Troque o host do Uvicorn por `127.0.0.1` e observe o smoke test do container.

## Referências oficiais

- <https://docs.github.com/pt/actions/tutorials/build-and-test-code/building-and-testing-python>
- <https://github.com/actions/checkout>
- <https://github.com/actions/setup-python>
- <https://github.com/actions/upload-artifact>
