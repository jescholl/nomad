job "webserver" {
  datacenters = ["dc1"]

  group "webserver" {
    network {
      port  "http" {}
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
        name = "webserver"
        port = "http"

        tags = [
          "testweb",
          "traefik.enable=true",
          "traefik.http.routers.webserver.entryPoints=internal",
          "prometheus.conf.metrics_path=/metrics",
          "prometheus.rules.0.alert='Webserver Down'",
          "prometheus.rules.0.expr=absent(up{job='webserver'})",
          "prometheus.rules.0.for=10s",
          "prometheus.rules.0.labels.severity=critical",
          "prometheus.rules.0.annotations.description='The webserver is down'",
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
