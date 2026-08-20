from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel, Field

app = FastAPI(
    title="API DevOps de Tarefas",
    description="API didática para demonstrar testes, CI e Docker.",
    version="1.0.0",
)


class TaskCreate(BaseModel):
    """Dados recebidos para criar uma tarefa."""

    title: str = Field(min_length=3, max_length=80, examples=["Estudar Actions"])


class Task(TaskCreate):
    """Tarefa devolvida pela API."""

    id: int
    done: bool = False


tasks: list[Task] = []


@app.get("/")
def root() -> dict[str, str]:
    return {
        "message": "API DevOps em execução",
        "docs": "/docs",
    }


@app.get("/health")
def health() -> dict[str, str]:
    """Endpoint usado por pessoas, containers e pipelines para verificar a API."""

    return {"status": "ok", "version": app.version}


@app.get("/tasks", response_model=list[Task])
def list_tasks() -> list[Task]:
    return tasks


@app.post("/tasks", response_model=Task, status_code=status.HTTP_201_CREATED)
def create_task(data: TaskCreate) -> Task:
    task = Task(id=len(tasks) + 1, title=data.title)
    tasks.append(task)
    return task


@app.patch("/tasks/{task_id}/done", response_model=Task)
def complete_task(task_id: int) -> Task:
    for task in tasks:
        if task.id == task_id:
            task.done = True
            return task
    raise HTTPException(status_code=404, detail="Tarefa não encontrada")
