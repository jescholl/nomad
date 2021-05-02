locals {
  service_name = "webserver"
}

job "webserver" {
  datacenters = ["dc1"]

  group "webserver" {
    network {
      port  "http" {}
    }

    task "configure_alerts" {
      lifecycle {
        hook = "prestart"
        sidecar = false
      }

      driver = "docker"
      config {
        image = "consul:${attr.consul.version}"
        network_mode = "host"
        args = [ "kv", "put", "config/prometheus/alerts/${local.service_name}", "@local/alerts.yml" ]
      }


      template {
        destination = "local/alerts.yml"
        data = yamlencode(
          {
            rules = [
              {
                alert = "Webserver Down"
                expr = "absent(up{job='${local.service_name}'})"
                for = "10s"
                labels = { severity = "critical" }
                annotations = { description = "The webserver is down" }
              }
            ]
          }
        )
      }
    }

    task "server" {
      driver = "docker"
      config {
        ports = ["http"]
        image = "hashicorp/demo-prometheus-instrumentation:latest"
      }

      resources {
        cpu = 500
        memory = 256
      }

      service {
        name = local.service_name
        port = "http"

        tags = [
          "testweb",
          "traefik.enable=true",
          "traefik.http.routers.webserver.entryPoints=internal",
          "prometheus.conf.metrics_path=/metrics",
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "2s"
          timeout  = "2s"
        }
      }
    }
  }
}
