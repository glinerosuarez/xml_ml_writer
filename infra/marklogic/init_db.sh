#!/usr/bin/env bash
set -euo pipefail

# Usage: init_db.sh <host> <new-db-port> <server-name> <db-name> <username> <password>
if [ "$#" -lt 6 ]; then
  echo "Usage: $0 <host> <new-db-port> <server-name> <db-name> <username> <password>"
  exit 1
fi

HOST="$1"
PORT="$2"
SERVER_NAME="$3"
DB_NAME="$4"
USER="$5"
PASS="$6"

FOREST_NAME="${DB_NAME}-1"
MGMT_URL="http://${HOST}:8002/v1/rest-apis"

# Check if the database already exists
HTTP_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" \
    --digest -u "${USER}:${PASS}" \
    "${MGMT_URL}/databases/${DB_NAME}?format=json" || echo 404)
if [ "$HTTP_STATUS" -eq 200 ]; then
    echo "Database '$DB_NAME' already exists"
else
    echo "Creating database '$DB_NAME'..."
    curl --silent --show-error -X POST --digest -u "${USER}:${PASS}" \
        -H "Content-Type:application/json" \
        -d '{"rest-api":{ "name":"'"${SERVER_NAME}"'","port":"'"${PORT}"'","database":"'"${DB_NAME}"'" }}' \
        "${MGMT_URL}"
    echo "Database '$DB_NAME' created"
fi

# Create a new role 'reader' via Manage API
ROLE_URL="http://${HOST}:8002/manage/v2/roles"
if curl --silent --digest -u "${USER}:${PASS}" "${ROLE_URL}/reader?format=json" --output /dev/null; then
  echo "Role 'reader' already exists"
else
  echo "Creating role 'reader'..."
  curl -X POST -i --digest -u "${USER}:${PASS}" -H "Content-Type:application/xml" \
    -d @roles/reader.xml $ROLE_URL
  echo "Role 'reader' created"
fi
