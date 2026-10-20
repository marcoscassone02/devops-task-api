#!/usr/bin/env bash

set -euo pipefail

: "${AWS_REGION:?AWS_REGION is required}"
: "${POSTGRES_EBS_VOLUME_ID:?POSTGRES_EBS_VOLUME_ID is required}"
: "${POSTGRES_PASSWORD_PARAMETER_NAME:?POSTGRES_PASSWORD_PARAMETER_NAME is required}"

readonly AWS_REGION
readonly POSTGRES_EBS_VOLUME_ID
readonly POSTGRES_PASSWORD_PARAMETER_NAME
readonly POSTGRES_MOUNT_POINT="/data/postgres"
readonly POSTGRES_FILESYSTEM_TYPE="xfs"
readonly POSTGRES_VOLUME_WAIT_ATTEMPTS=60
readonly POSTGRES_VOLUME_WAIT_SECONDS=5

find_postgres_device() {
  local device
  local serial
  local expected_serial="${POSTGRES_EBS_VOLUME_ID//-/}"

  while read -r device serial; do
    if [[ "${serial//-/}" == "${expected_serial}" ]]; then
      printf '%s\n' "${device}"
      return 0
    fi
  done < <(lsblk -dpno NAME,SERIAL)

  return 1
}

readonly APP_DIR="/opt/devops-task-api"
readonly REPOSITORY_URL="https://github.com/marcoscassone02/devops-task-api.git"
readonly COMPOSE_VERSION="v5.6.0"
readonly COMPOSE_ASSET="docker-compose-linux-x86_64"
readonly COMPOSE_PLUGIN_DIR="/usr/local/lib/docker/cli-plugins"
readonly COMPOSE_DOWNLOAD_URL="https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}"

dnf update -y
dnf install -y docker git xfsprogs

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

postgres_device=""

for ((attempt = 1; attempt <= POSTGRES_VOLUME_WAIT_ATTEMPTS; attempt++)); do
  if postgres_device="$(find_postgres_device)"; then
    break
  fi

  sleep "${POSTGRES_VOLUME_WAIT_SECONDS}"
done

if [[ -z "${postgres_device}" ]]; then
  echo "PostgreSQL EBS volume ${POSTGRES_EBS_VOLUME_ID} was not attached" >&2
  exit 1
fi

filesystem_type="$(blkid -s TYPE -o value "${postgres_device}" || true)"

if [[ -z "${filesystem_type}" ]]; then
  mkfs -t "${POSTGRES_FILESYSTEM_TYPE}" -L pgdata "${postgres_device}"
elif [[ "${filesystem_type}" != "${POSTGRES_FILESYSTEM_TYPE}" ]]; then
  echo "Unexpected filesystem ${filesystem_type} on ${postgres_device}" >&2
  exit 1
fi

install -d -m 0755 "${POSTGRES_MOUNT_POINT}"

filesystem_uuid="$(blkid -s UUID -o value "${postgres_device}")"
fstab_entry="UUID=${filesystem_uuid} ${POSTGRES_MOUNT_POINT} ${POSTGRES_FILESYSTEM_TYPE} defaults,nofail 0 2"

if ! grep -Fq "UUID=${filesystem_uuid} " /etc/fstab; then
  printf '%s\n' "${fstab_entry}" >> /etc/fstab
fi

if ! mountpoint -q "${POSTGRES_MOUNT_POINT}"; then
  mount "${POSTGRES_MOUNT_POINT}"
fi

mounted_source="$(findmnt -n -o SOURCE --target "${POSTGRES_MOUNT_POINT}")"
mounted_uuid="$(blkid -s UUID -o value "${mounted_source}")"

if [[ "${mounted_uuid}" != "${filesystem_uuid}" ]]; then
  echo "PostgreSQL EBS volume was not mounted correctly" >&2
  exit 1
fi

if [[ ! -d "${APP_DIR}/.git" ]]; then
  git clone \
    --branch main \
    --single-branch \
    "${REPOSITORY_URL}" \
    "${APP_DIR}"
else
  git -C "${APP_DIR}" pull --ff-only origin main
fi

umask 077

database_password="$(
  aws ssm get-parameter \
    --name "${POSTGRES_PASSWORD_PARAMETER_NAME}" \
    --with-decryption \
    --region "${AWS_REGION}" \
    --query "Parameter.Value" \
    --output text
)"

if [[ -z "${database_password}" ]]; then
  echo "PostgreSQL password parameter is empty" >&2
  exit 1
fi

printf \
  'POSTGRES_DB=devops_tasks\nPOSTGRES_USER=devops_user\nPOSTGRES_PASSWORD=%s\nIMAGE_TAG=latest\n' \
  "${database_password}" > "${APP_DIR}/.env"

chmod 0600 "${APP_DIR}/.env"
unset database_password

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