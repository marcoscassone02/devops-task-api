from pydantic import BaseModel, Field


class TaskCreate(BaseModel):
    title: str = Field(min_length=1, max_length=100)
    description: str | None = Field(default=None, max_length=500)


class Task(TaskCreate):
    id: int
    completed: bool = False

class TaskUpdate(BaseModel):
    completed: bool