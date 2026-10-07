FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

LABEL org.opencontainers.image.source="https://github.com/marcoscassone02/devops-task-api"

COPY requirements.txt .
RUN pip install --no-cache-dir --requirement requirements.txt

COPY app ./app

COPY alembic.ini .
COPY migrations ./migrations

FROM base AS test

COPY requirements-dev.txt .
RUN pip install --no-cache-dir --requirement requirements-dev.txt

COPY ruff.toml .
COPY tests ./tests

CMD ["python", "-m", "pytest", "-q"]

FROM base AS runtime

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
