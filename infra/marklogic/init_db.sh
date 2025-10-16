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

# Create the database with its forest
 echo "Creating database '$DB_NAME' with forest '$FOREST_NAME'..."
JSON_PAYLOAD=$(cat <<EOF
{
  "database-name": "${DB_NAME}",
  "forest": [{"forest-name": "${FOREST_NAME}"}]
}
EOF
)
HTTP_RESPONSE=$(curl --silent --show-error --digest -u "${USER}:${PASS}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d "$JSON_PAYLOAD" \
  -w "%{http_code}" \
  --output /dev/null \
  "${MGMT_URL}/databases?format=json")
if [[ "$HTTP_RESPONSE" -ge 200 && "$HTTP_RESPONSE" -lt 300 ]]; then
  echo "Database '$DB_NAME' created successfully (HTTP $HTTP_RESPONSE)."
else
  echo "Error: failed to create database '$DB_NAME' (HTTP $HTTP_RESPONSE)."
  exit 1
fi

echo "Request to create database '$DB_NAME' submitted"