job "smokeping" {
  datacenters = ["dc1"]
  type = "service"
  group "main" {
    count = 1

    network {
      port "http" { to = 80 }
    }

    task "smokeping" {
      driver = "docker"
      config {
        image = "linuxserver/smokeping:latest"
        ports = ["http"]
        volumes = [
          "local/Targets:/config/Targets",
        ]

        mount {
          type = "volume"
          target = "/config"
          source = "smokeping_config"
          readonly = false
          volume_options {
            no_copy = false
            driver_config {
              name = "pxd"
              options {
                size = "1G"
                repl = "2"
              }
            }
          }
        }

        mount {
          type = "volume"
          target = "/data"
          source = "smokeping_data"
          readonly = false
          volume_options {
            no_copy = false
            driver_config {
              name = "pxd"
              options {
                size = "1G"
                repl = "2"
              }
            }
          }
        }
      }

      resources {
        cpu    = 10
        memory = 256
      }

      service {
        name = "smokeping"
        port = "http"

        tags = [
          "traefik.http.middlewares.smokeping-strip-prefix.stripprefix.prefixes=/smokeping/",
          "traefik.http.middlewares.smokeping-add-prefix.addprefix.prefix=/smokeping/",
          "traefik.http.routers.smokeping.middlewares=smokeping-strip-prefix@consulcatalog,smokeping-add-prefix@consulcatalog",
          "traefik.enable=true",
          "traefik.http.routers.smokeping.entryPoints=internal"
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "2s"
        }
      }

      template {
        destination = "local/Targets"
        data = file("targets.ctpl")
      }
    }
  }
}
