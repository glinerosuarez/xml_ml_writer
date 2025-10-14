terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

locals {
  marklogic_ports = [for port in range(8000, 8101) : port]
}

variable "admin_password" {
  type        = string
  description = "MarkLogic admin password"
  default     = "admin"
  sensitive   = true
}

resource "docker_image" "marklogic" {
  name         = "progressofficial/marklogic-db:latest"
  keep_locally = true
}

resource "docker_volume" "marklogic" {
  name = "ml_vol_1"
}

resource "docker_container" "marklogic" {
  name  = "marklogic-local"
  image = docker_image.marklogic.image_id

  env = [
    "MARKLOGIC_ADMIN_USERNAME=admin",
    "MARKLOGIC_ADMIN_PASSWORD=${var.admin_password}",
    "MARKLOGIC_INIT=true"
  ]

  dynamic "ports" {
    for_each = local.marklogic_ports
    content {
      internal = ports.value
      external = ports.value
    }
  }

  restart = "unless-stopped"

  volumes {
    volume_name    = docker_volume.marklogic.name
    container_path = "/var/opt/MarkLogic"
  }

  healthcheck {
    test     = ["CMD", "curl", "-f", "--digest", "-u", "admin:${var.admin_password}", "http://localhost:8001/admin/v1/timestamp"]
    interval = "30s"
    timeout  = "5s"
    retries  = 10
  }
}

resource "null_resource" "marklogic_protein_db" {
  depends_on = [docker_container.marklogic]

  triggers = {
    database_name = "protein"
    admin_password = var.admin_password
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -euo pipefail

      echo "Waiting for MarkLogic Manage API to become available..."
      until curl --silent --digest -u admin:${var.admin_password} \
        http://localhost:8002/manage/v2/databases?format=json >/dev/null 2>&1; do
        sleep 5
      done

      STATUS=$(curl --silent --output /dev/null --write-out "%%{http_code}" \
        --digest -u admin:${var.admin_password} \
        http://localhost:8002/manage/v2/databases/protein?format=json || true)

      if [[ "$STATUS" == "200" ]]; then
        echo "Database protein already exists; skipping creation."
      else
        echo "Creating MarkLogic database 'protein'..."
        curl --silent --show-error --digest -u admin:${var.admin_password} \
          -H "Content-Type: application/json" \
          -H "Accept: application/json" \
          -X POST \
          -d '{"database-name":"protein","forests":[{"forest-name":"protein-1"}]}' \
          http://localhost:8002/manage/v2/databases
        echo
      fi
    EOT
  }
}