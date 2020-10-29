job "webserver" {
  datacenters = ["dc1"]

  group "webserver" {
    task "server" {
      driver = "docker"
      config {
        image = "hashicorp/demo-prometheus-instrumentation:latest"
      }

      resources {
        cpu = 500
        memory = 256
        network {
          mbits = 10
          port  "http"{}
        }
      }

      service {
        name = "webserver"
        port = "http"

        tags = [
          "testweb",
          "traefik.enable=true",
          "traefik.http.routers.webserver.entryPoints=internal",
          "prometheus.metrics_path=/metrics",
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
