# DevOps Task API

Task-management API built as a hands-on Cloud/DevOps portfolio project. The
repository demonstrates application development, containerization, automated
quality checks, image publication, infrastructure as code, secret management,
and deployment to AWS.

## Architecture

```text
Developer
  |
  | Git push / pull request
  v
GitHub Actions
  |-- Ruff + pytest + pip-audit
  |-- build + Trivy scan
  |-- publish runtime image to GHCR
  `-- deploy exact image through OIDC + Systems Manager

AWS
  |
  v
Public subnet + security group (TCP 8000 restricted to one /32)
  |
  v
EC2 Amazon Linux 2023 (managed through Systems Manager)
  |-- FastAPI container
  |-- Alembic migration container
  |-- PostgreSQL 16 container
  |       |
  |       v
  |   encrypted persistent EBS mounted at /data/postgres
  |
  `-- Docker awslogs driver
          |
          v
      CloudWatch Logs
          |-- application error metric
          |-- EC2 and application alarms
          `-- operational dashboard
```

The API and PostgreSQL currently run as containers on one EC2 instance. The
instance is replaceable; PostgreSQL data is kept on a separate EBS volume.

## Implemented features

- FastAPI CRUD API with interactive documentation.
- PostgreSQL 16 through SQLAlchemy 2 and Psycopg.
- Alembic migrations executed before the API starts.
- Pytest tests with an isolated in-memory SQLite database.
- Multi-stage Dockerfile with `runtime` and `test` targets.
- Docker Compose health checks and dependency ordering.
- Ruff linting, dependency auditing with pip-audit, and image scanning with
  Trivy.
- GitHub Actions CI on pull requests and pushes to `main`.
- Automatic runtime-image publication to GitHub Container Registry (GHCR).
- AWS infrastructure managed with Terraform and remote state in S3.
- VPC, public subnet, internet gateway, route table, security group, IAM role,
  EC2, encrypted EBS, and SSM Parameter Store.
- EC2 access through AWS Systems Manager Session Manager without inbound SSH.
- Automated EC2 bootstrap that installs Docker Compose, mounts the PostgreSQL
  EBS volume, retrieves the database password, pulls the GHCR image, runs
  migrations, and starts the application.
- Automated application deployment through GitHub Actions, OIDC, Systems
  Manager, immutable image tags, and a final health check.
- Centralized container logs in CloudWatch Logs with seven-day retention.
- CloudWatch metric filter, application and EC2 alarms, and an operational
  dashboard managed with Terraform.
- PostgreSQL data verified to survive an EC2 replacement.

## Main technologies

Python 3.12, FastAPI, Uvicorn, SQLAlchemy 2, Psycopg, PostgreSQL 16, Alembic,
pytest, Ruff, pip-audit, Docker, Docker Compose, Trivy, GitHub Actions, GHCR,
Terraform, Amazon EC2, Amazon EBS, Amazon S3, IAM, Systems Manager, Parameter
Store, and Amazon CloudWatch.

## Run locally

Requirements:

- Docker
- Docker Compose

Create the local configuration:

```bash
cp .env.example .env
```

Replace the example password and start the application:

```bash
docker compose up --build --detach
```

Compose follows this startup order:

```text
PostgreSQL healthy -> alembic upgrade head -> FastAPI
```

Endpoints:

- Health check: <http://localhost:8000/health>
- Swagger UI: <http://localhost:8000/docs>
- Tasks: <http://localhost:8000/tasks>

Inspect or stop the environment:

```bash
docker compose ps --all
docker compose logs --follow
docker compose down
```

`docker compose down` preserves the database. To intentionally remove the local
database volume, use `docker compose down --volumes`.

## Tests and quality checks

Run the test service:

```bash
docker compose run --rm --build test
```

Or build the test image and run each check separately:

```bash
docker build --target test --tag devops-task-api:test .
docker run --rm devops-task-api:test ruff check .
docker run --rm devops-task-api:test pip-audit --requirement requirements.txt
docker run --rm \
  --env DATABASE_URL=sqlite+pysqlite:///:memory: \
  devops-task-api:test
```

## Database migrations

Generate and review a migration after changing a SQLAlchemy model:

```bash
docker compose run --rm migrate \
  alembic revision --autogenerate -m "describe the schema change"
```

Apply pending migrations:

```bash
docker compose run --rm migrate
```

The `migrate` service runs `alembic upgrade head`. The first project migration
is `fcbd5f880c30`.

`alembic stamp head` is only for adopting a database whose schema already
matches the migrations. It records the revision without executing schema
changes.

## CI/CD and container images

`.github/workflows/ci.yml` runs on pull requests to `main` and pushes to
`main`. The `quality` job runs Ruff, pip-audit, pytest, builds the runtime image,
and scans it with Trivy. On a successful push to `main`, the `publish` job
publishes these tags:

```text
ghcr.io/marcoscassone02/devops-task-api:latest
ghcr.io/marcoscassone02/devops-task-api:<commit-sha>
```

Pull the latest published image:

```bash
docker pull ghcr.io/marcoscassone02/devops-task-api:latest
```

After publishing an image, the `deploy` job obtains temporary AWS credentials
through GitHub OIDC, sends the exact commit SHA to EC2 through Systems Manager,
updates the containers, and verifies the `/health` endpoint. No permanent AWS
access keys are stored in GitHub.

`compose.yaml` builds from local source. `compose.deploy.yaml` is an override
used on EC2: it pulls the published image, binds `/data/postgres` to the
PostgreSQL data directory, and sends container logs to CloudWatch.

## AWS infrastructure

Terraform code is split into:

- `infra/bootstrap`: creates the protected, encrypted, versioned S3 bucket used
  for remote Terraform state.
- `infra/terraform`: creates networking, IAM, EC2, EBS, Parameter Store, and the
  application bootstrap and observability configuration.

Important infrastructure behavior:

- The EC2 root EBS volume is replaceable and deleted with the instance.
- The separate 10 GiB PostgreSQL EBS volume is encrypted and protected with
  `prevent_destroy`.
- The PostgreSQL password is a `SecureString` in Parameter Store and is read by
  the EC2 IAM role using least-privilege permissions.
- The API port is restricted to the configured developer IPv4 `/32` CIDR.
- No inbound port 22 is required; administration uses Session Manager.
- Changing `user_data` replaces EC2, after which the existing PostgreSQL EBS is
  attached and mounted automatically.

Typical Terraform workflow:

```bash
aws login --profile devops-task-api

AWS_PROFILE=devops-task-api terraform -chdir=infra/terraform init
AWS_PROFILE=devops-task-api terraform -chdir=infra/terraform fmt -check -recursive
AWS_PROFILE=devops-task-api terraform -chdir=infra/terraform validate
AWS_PROFILE=devops-task-api terraform -chdir=infra/terraform plan -out=plan.tfplan
AWS_PROFILE=devops-task-api terraform -chdir=infra/terraform apply plan.tfplan
AWS_PROFILE=devops-task-api terraform -chdir=infra/terraform output
```

Before applying a plan that replaces EC2 or changes storage, review the plan and
create a consistent EBS snapshot when appropriate.

## Access the deployed instance

Get the instance ID and connect with Session Manager:

```bash
INSTANCE_ID="$(AWS_PROFILE=devops-task-api \
  terraform -chdir=infra/terraform output -raw api_instance_id)"

AWS_PROFILE=devops-task-api aws ssm start-session \
  --target "${INSTANCE_ID}" \
  --region us-east-1
```

Useful checks inside EC2:

```bash
sudo cloud-init status --wait
findmnt /data/postgres
sudo docker compose \
  -p devops-task-api \
  -f /opt/devops-task-api/compose.yaml \
  -f /opt/devops-task-api/compose.deploy.yaml \
  ps
curl -fsS http://localhost:8000/health
```

## Observability

The production Compose override sends the standard output and error streams of
the API, migration, and PostgreSQL containers to this CloudWatch log group:

```text
/devops-task-api/dev/containers
```

Terraform configures seven-day retention, an error metric filter, alarms for
application errors, high EC2 CPU, and failed EC2 status checks, plus the
`devops-task-api-dev` dashboard.

Read recent logs:

```bash
AWS_PROFILE=devops-task-api aws logs tail \
  /devops-task-api/dev/containers \
  --region us-east-1 \
  --since 10m
```

Add `--follow` to keep streaming new events.

## Security and limitations

- Secrets and Terraform variable files are ignored by Git.
- EBS volumes, snapshots, EC2, public IPv4 addresses, and other AWS resources
  can generate charges while they exist.
- This is a development/portfolio architecture. PostgreSQL is self-managed on
  the same EC2 host as the API; a production evolution could use an Application
  Load Balancer, HTTPS, managed DNS, Amazon RDS, automated backups, and a
  high-availability architecture.

## Roadmap

- [x] CRUD API, tests, PostgreSQL, and Alembic.
- [x] Multi-stage Docker images and Docker Compose.
- [x] CI quality and security checks.
- [x] Image publication to GHCR.
- [x] Terraform remote state and AWS networking.
- [x] EC2 deployment through automated bootstrap.
- [x] Persistent PostgreSQL EBS and Parameter Store secret.
- [x] Automated application deployment after publishing an image.
- [x] Centralized logs, metrics, dashboard, and alarms.
- [ ] HTTPS and stable DNS endpoint.
- [ ] Managed database and high-availability architecture.
