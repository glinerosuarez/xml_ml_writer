#!/usr/bin/env bash
set -euo pipefail

# Usage: init_db.sh <host> <port> <username> <password>
if [ "$#" -lt 4 ]; then
  echo "Usage: $0 <host> <port> <username> <password>"
  exit 1
fi

HOST="$1"
PORT="$2"
USER="$3"
PASS="$4"
DB_NAME="protein"
FOREST_NAME="${DB_NAME}-1"
MGMT_URL="http://${HOST}:${PORT}/manage/v2"

# Check if the database already exists
HTTP_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" --digest -u "${USER}:${PASS}" \
  "${MGMT_URL}/databases/${DB_NAME}?format=json" || echo 404)
if [ "$HTTP_STATUS" -eq 200 ]; then
  echo "Database '$DB_NAME' already exists"
  exit 0
fi

# Create the database by passing parameters in the query string
#echo "Creating database '$DB_NAME' with forest '$FOREST_NAME'..."
#if curl --silent --show-error --fail --digest -u "${USER}:${PASS}" \
#     -X POST "${MGMT_URL}/databases?database-name=${DB_NAME}&forest=${FOREST_NAME}"; then
#  echo "Database '$DB_NAME' created successfully."
#else
#  echo "Error: failed to create database '$DB_NAME' via Manage API." >&2
#  exit 1
#fi

#echo "Request to create database '$DB_NAME' submitted"