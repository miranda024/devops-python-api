# Roteiro sugerido para apresentação

## Objetivo

Ao final, os estudantes devem explicar como uma mudança percorre o caminho:

```text
commit → workflow → qualidade → testes → imagem → container → evidência
```

## Bloco 1 — Conhecer a API (25 min)

1. Apresente a estrutura do repositório.
2. Inicie o Uvicorn localmente.
3. Abra `/docs` e execute `GET /health`.
4. Crie uma tarefa válida.
5. Envie um título com dois caracteres e observe o `422`.

Pergunta para a turma: quais comportamentos precisam continuar verdadeiros após uma mudança?

## Bloco 2 — Transformar comportamento em teste (25 min)

1. Abra `tests/test_api.py`.
2. Relacione preparação, ação e asserção.
3. Execute `pytest -v`.
4. Mostre a cobertura e discuta o que ela mede e o que não garante.
5. Altere a versão de `/health` para provocar falha.

Checkpoint: a turma deve localizar o primeiro valor esperado diferente do recebido.

## Bloco 3 — Ler o workflow (35 min)

1. Comece pelos eventos, não pelos comandos.
2. Mostre `permissions` e `concurrency`.
3. Leia o primeiro job step a step.
4. Explique `uses` versus `run`.
5. Mostre `needs` conectando os dois jobs.
6. Faça push da versão corrigida.

Checkpoint: peça que um estudante preveja a ordem dos jobs antes de abrir Actions.

## Bloco 4 — Diagnosticar CI (25 min)

1. Adicione `import os` sem uso.
2. Faça commit e push.
3. Abra Actions → execução → job → step do Ruff.
4. Corrija e envie novo commit.
5. Compare os dois logs e os hashes dos commits.

Mensagem central: falha de pipeline é evidência localizada, não um veredito sobre todo o projeto.

## Intervalo sugerido — 15 min

## Bloco 5 — Construir e executar a imagem (35 min)

1. Leia o Dockerfile de cima para baixo.
2. Destaque a ordem das camadas.
3. Execute `docker build` duas vezes e compare o cache.
4. Execute o container e chame `/health`.
5. Mostre imagem, container, logs e estado de saúde.

Checkpoint: os estudantes devem distinguir `EXPOSE` de `--publish`.

## Bloco 6 — Falha de rede (25 min)

1. Troque `0.0.0.0` por `127.0.0.1`.
2. Reconstrua com outra tag.
3. Mostre que o processo iniciou pelos logs.
4. Mostre que o `curl` falha.
5. Corrija, reconstrua e valide.

Pergunta para a turma: por que publicar a porta não corrige o endereço em que o processo escuta?

## Bloco 7 — Prática em duplas (45 min)

Uma pessoa dirige e a outra explica. Troque os papéis após o primeiro teste.

Desafio:

1. criar `DELETE /tasks/{id}`;
2. escrever teste de sucesso e teste `404`;
3. executar Ruff e pytest localmente;
4. fazer push em uma branch;
5. abrir pull request;
6. usar o resultado da CI como evidência para o merge.

## Fechamento (10 min)

Peça um exit ticket com quatro respostas:

1. Qual evento iniciou o workflow?
2. Qual step comprova o comportamento da API?
3. Qual job só roda após os testes?
4. Qual evidência mostra que a aplicação funciona dentro do container?
