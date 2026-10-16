#!/usr/bin/env bash

set -euo pipefail

readonly APP_DIR="/opt/devops-task-api"
readonly REPOSITORY_URL="https://github.com/marcoscassone02/devops-task-api.git"
readonly COMPOSE_VERSION="v5.6.0"
readonly COMPOSE_ASSET="docker-compose-linux-x86_64"
readonly COMPOSE_PLUGIN_DIR="/usr/local/lib/docker/cli-plugins"
readonly COMPOSE_DOWNLOAD_URL="https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}"

dnf update -y
dnf install -y docker git curl openssl

systemctl enable --now docker

install -d -m 0755 "${COMPOSE_PLUGIN_DIR}"

temporary_directory="$(mktemp -d)"

curl -fsSL \
  "${COMPOSE_DOWNLOAD_URL}/${COMPOSE_ASSET}" \
  -o "${temporary_directory}/${COMPOSE_ASSET}"

curl -fsSL \
  "${COMPOSE_DOWNLOAD_URL}/${COMPOSE_ASSET}.sha256" \
  -o "${temporary_directory}/${COMPOSE_ASSET}.sha256"

(
  cd "${temporary_directory}"
  sha256sum -c "${COMPOSE_ASSET}.sha256"
)

install \
  -m 0755 \
  "${temporary_directory}/${COMPOSE_ASSET}" \
  "${COMPOSE_PLUGIN_DIR}/docker-compose"

if [[ ! -d "${APP_DIR}/.git" ]]; then
  git clone \
    --branch main \
    --single-branch \
    "${REPOSITORY_URL}" \
    "${APP_DIR}"
else
  git -C "${APP_DIR}" pull --ff-only origin main
fi

if [[ ! -f "${APP_DIR}/.env" ]]; then
  umask 077

  database_password="$(openssl rand -hex 32)"

  printf \
    'POSTGRES_DB=devops_tasks\nPOSTGRES_USER=devops_user\nPOSTGRES_PASSWORD=%s\nIMAGE_TAG=latest\n' \
    "${database_password}" > "${APP_DIR}/.env"

  unset database_password
fi

docker compose \
  -p devops-task-api \
  -f "${APP_DIR}/compose.yaml" \
  -f "${APP_DIR}/compose.deploy.yaml" \
  pull

docker compose \
  -p devops-task-api \
  -f "${APP_DIR}/compose.yaml" \
  -f "${APP_DIR}/compose.deploy.yaml" \
  up -d