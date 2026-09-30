# DevOps Task API

A small task-management API built as a hands-on Cloud and DevOps portfolio
project. The application will evolve incrementally to include PostgreSQL,
automated tests, CI/CD, infrastructure as code, monitoring, and cloud deployment.

## Current milestone

The first milestone provides:

- A FastAPI service.
- A health endpoint at `GET /health`.
- Interactive API documentation at `/docs`.
- A production-style Docker image.
- Docker Compose orchestration and a container health check.
- An automated health endpoint test.

## Run locally

```bash
docker compose up --build
```

Then open:

- API health: <http://localhost:8000/health>
- Interactive documentation: <http://localhost:8000/docs>

Stop and remove the container with:

```bash
docker compose down
```

## Run tests

Run the tests in their dedicated container image:

```bash
docker compose run --rm --build test
```

## Roadmap

- Task CRUD endpoints.
- PostgreSQL persistence and migrations.
- Nginx reverse proxy.
- GitHub Actions CI pipeline.
- Metrics, dashboards, and alerting.
- Cloud infrastructure managed with Terraform.
