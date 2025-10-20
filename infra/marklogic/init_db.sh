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
ROLES_URL="http://${HOST}:8002/manage/v2/roles"
DB_URL="http://${HOST}:8002/manage/v2/databases/${DB_NAME}"

# Check if the database already exists
get_http_status() {
    local url="$1"
    curl --silent --output /dev/null --write-out "%{http_code}" \
        --digest -u "${USER}:${PASS}" \
        "$url" || echo 404
}

# function to create a role via Manage API, returns HTTP status
create_role() {
    local role_name="$1"
    ROLE_HTTP_STATUS=$(get_http_status "${ROLES_URL}/${role_name}?format=json")
    if [ "$ROLE_HTTP_STATUS" -eq 200 ]; then
        echo "Role '${role_name}' already exists"
    else
        echo "Creating role '${role_name}'..."
        ROLE_HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST --digest -u "${USER}:${PASS}" \
            -H "Content-Type:application/xml" \
            -d @infra/marklogic/roles/"${role_name}".xml \
            "${ROLES_URL}")
        
        if [ "$ROLE_HTTP_STATUS" -eq 201 ]; then
            echo "Role '${role_name}' created"
            # update role with permissions
            PERM_HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT --digest -u "${USER}:${PASS}" \
                -H "Content-Type:application/xml" \
                -d @infra/marklogic/roles/"${role_name}"_permissions.xml \
                "${ROLES_URL}/${role_name}/properties")
            if [ "$PERM_HTTP_STATUS" -eq 200 ]; then
                echo "Permissions for role '${role_name}' updated"
            else
                echo "Failed to update permissions for role '${role_name}'"
                echo "HTTP Status: $PERM_HTTP_STATUS"
                exit 1
            fi
        else
            echo "Failed to create role '${role_name}'"
            echo "HTTP Status: $ROLE_HTTP_STATUS"
            exit 1
        fi
    fi
}

HTTP_STATUS=$(get_http_status "${DB_URL}?format=json")
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
create_role "reader"

# Create a new role 'protein_analyst' via Manage API
create_role "protein_analyst"

# Create a new role 'protein_loader' via Manage API
create_role "protein_loader"