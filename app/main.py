
from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Task as TaskModel
from app.schemas import Task as TaskSchema
from app.schemas import TaskCreate, TaskUpdate

app = FastAPI(
    title="DevOps Task API",
    description="A small API used to practice production-ready DevOps workflows.",
    version="0.1.0"
)


@app.get("/health", tags=["Operations"])
def health_check() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/")
def root() -> dict[str, str]:
    return {"message": "DevOps Task API"}


@app.post(
    "/tasks",
    response_model=TaskSchema,
    status_code=201,
    tags=["Tasks"],
)
def create_task(
    task_data: TaskCreate,
    database: Session = Depends(get_db),
) -> TaskModel:
    task = TaskModel(
        title=task_data.title,
        description=task_data.description,
    )

    database.add(task)
    database.commit()
    database.refresh(task)

    return task


@app.get(
    "/tasks",
    response_model=list[TaskSchema],
    tags=["Tasks"],
)
def list_tasks(
    database: Session = Depends(get_db),
) -> list[TaskModel]:
    statement = select(TaskModel).order_by(TaskModel.id)

    return list(database.scalars(statement))


@app.get(
    "/tasks/{task_id}",
    response_model=TaskSchema,
    tags=["Tasks"],
)
def get_task(
    task_id: int,
    database: Session = Depends(get_db),
) -> TaskModel:
    task = database.get(TaskModel, task_id)

    if task is None:
        raise HTTPException(
            status_code=404,
            detail="Task not found",
        )

    return task


@app.patch(
    "/tasks/{task_id}",
    response_model=TaskSchema,
    tags=["Tasks"],
)
def update_task(
    task_id: int,
    task_data: TaskUpdate,
    database: Session = Depends(get_db),
) -> TaskModel:
    task = database.get(TaskModel, task_id)

    if task is None:
        raise HTTPException(
            status_code=404,
            detail="Task not found",
        )

    task.completed = task_data.completed

    database.commit()
    database.refresh(task)

    return task


@app.delete(
    "/tasks/{task_id}",
    status_code=204,
    tags=["Tasks"],
)
def delete_task(
    task_id: int,
    database: Session = Depends(get_db),
) -> None:
    task = database.get(TaskModel, task_id)

    if task is None:
        raise HTTPException(
            status_code=404,
            detail="Task not found",
        )

    database.delete(task)
    database.commit()