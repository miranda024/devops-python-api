# Entendendo a API em Python

## Por que FastAPI?

FastAPI permite demonstrar rotas, validação e documentação interativa com pouco código. Ao iniciar a aplicação, a especificação OpenAPI e a interface Swagger são geradas automaticamente em `/docs`.

## Ponto de entrada

O objeto abaixo representa a aplicação ASGI que o Uvicorn executa:

```python
app = FastAPI(
    title="API DevOps de Tarefas",
    description="API didática para demonstrar testes, CI e Docker.",
    version="1.0.0",
)
```

O comando `uvicorn app.main:app` deve ser lido assim:

- `app`: pacote/diretório;
- `main`: módulo `main.py`;
- `app`: variável que contém a instância de `FastAPI`.

## Modelos e validação

`TaskCreate` representa o corpo aceito pelo endpoint de criação. O título deve ter entre 3 e 80 caracteres.

```python
class TaskCreate(BaseModel):
    title: str = Field(min_length=3, max_length=80)
```

Se a entrada violar essa regra, o framework responde `422` antes de chamar a função da rota. O teste `test_rejects_short_title` transforma essa regra em evidência automatizada.

`Task` acrescenta os dados gerados pela aplicação:

```python
class Task(TaskCreate):
    id: int
    done: bool = False
```

## Rotas

Uma rota liga método HTTP, caminho e função:

```python
@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "version": app.version}
```

O endpoint `/health` é propositalmente simples. Ele é reutilizado pelo navegador, por `curl`, pelo `HEALTHCHECK` do Docker e pelo smoke test do pipeline.

## Armazenamento em memória

```python
tasks: list[Task] = []
```

Essa lista existe somente no processo atual. Ao reiniciar o servidor ou substituir o container, os dados desaparecem. Isso é intencional para a aula: persistência e bancos podem ser acrescentados depois.

## Testes

O `TestClient` chama a aplicação sem abrir uma porta real:

```python
client = TestClient(app)
response = client.get("/health")
assert response.status_code == 200
```

A fixture automática limpa a lista antes de cada teste. Assim, nenhum teste depende da ordem de execução:

```python
@pytest.fixture(autouse=True)
def clear_tasks() -> None:
    tasks.clear()
```

Esse isolamento é importante em CI: um teste deve produzir o mesmo resultado quando executado sozinho, em outra ordem ou em outro computador.

## Sequência sugerida para explicar o código

1. Execute `/health` e mostre JSON e status HTTP.
2. Abra `/docs` e crie uma tarefa pelo Swagger.
3. Mostre o modelo `TaskCreate` e provoque uma validação `422`.
4. Abra um teste e relacione entrada, ação e resultado esperado.
5. Execute `pytest -v`.
6. Altere a versão do health check e observe a falha localizada.
