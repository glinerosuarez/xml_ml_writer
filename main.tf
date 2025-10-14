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