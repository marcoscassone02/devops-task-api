from fastapi import FastAPI, HTTPException
from app.schemas import Task, TaskCreate, TaskUpdate
app = FastAPI(
    title="DevOps Task API",
    description="A small API used to practice production-ready DevOps workflows.",
    version="0.1.0",
)

tasks: list[Task] = []
next_task_id = 1


@app.get("/health", tags=["Operations"])
def health_check() -> dict[str, str]:
    """Return the service health status."""
    return {"status": "ok"}

@app.post("/tasks", response_model=Task, status_code=201, tags=["Tasks"])
def create_task(task_data: TaskCreate) -> Task:
    global next_task_id

    task = Task(
        id=next_task_id,
        title=task_data.title,
        description=task_data.description,
    )

    tasks.append(task)
    next_task_id += 1

    return task


@app.get("/tasks", response_model=list[Task], tags=["Tasks"])
def list_tasks() -> list[Task]:
    return tasks

@app.get("/tasks/{task_id}", response_model=Task, tags=["Tasks"])
def get_task(task_id: int) -> Task:
    for task in tasks:
        if task.id == task_id:
            return task

    raise HTTPException(status_code=404, detail="Task not found")

@app.patch("/tasks/{task_id}", response_model=Task, tags=["Tasks"])
def update_task(task_id: int, task_data: TaskUpdate) -> Task:
    for task in tasks:
        if task.id == task_id:
            task.completed = task_data.completed
            return task

    raise HTTPException(status_code=404, detail="Task not found")

@app.delete("/tasks/{task_id}", status_code=204, tags=["Tasks"])
def delete_task(task_id: int) -> None:
    for index, task in enumerate(tasks):
        if task.id == task_id:
            tasks.pop(index)
            return

    raise HTTPException(status_code=404, detail="Task not found")

@app.get("/")
def root() -> dict[str, str]:
    return {"message": "DevOps Task API"}