from pydantic import BaseModel, ConfigDict, Field



class TaskCreate(BaseModel):
    title: str = Field(min_length=1, max_length=100)
    description: str | None = Field(default=None, max_length=500)


class Task(TaskCreate):
    model_config = ConfigDict(from_attributes=True)

    id: int
    completed: bool = False

class TaskUpdate(BaseModel):
    completed: bool