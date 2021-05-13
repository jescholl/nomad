job "grafana" {
  datacenters = ["dc1"]
  type = "service"

  group "main" {
    count = 1

    network {
      port "web" { to = 3000 }
    }

    task "grafana" {
      driver = "docker"
      config {
        ports = ["web"]
        image = "grafana/grafana:latest"

        mount {
          target = "/var/lib/grafana"
          source = "grafana"
          volume_options {
            driver_config {
              name = "pxd"
              options {
                size = "2G"
                repl = "2"
              }
            }
          }
        }
      }

      resources {
        cpu = 10
        memory = 300
      }

      env {
        GF_INSTALL_PLUGINS = "grafana-piechart-panel,natel-discrete-panel"
      }

      service {
        name = "grafana"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.grafana.entryPoints=internal",
        ]

        port = "web"

        check {
          type     = "http"
          path     = "/api/health"
          interval = "30s"
          timeout  = "2s"
        }
      }
    }
  }
}
