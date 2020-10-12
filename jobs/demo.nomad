job "demo-webapp" {
  datacenters = ["dc1"]

  group "demo" {
    count = 3

    update {
      max_parallel     = 3
      canary           = 3
      auto_revert      = true
      auto_promote     = true
    }

    task "server" {
      driver = "docker"
      shutdown_delay = "30s" # must be higher than traefik's refresh interval

      env {
        VERSION = "1.0.15"
      }

      config {
        image = "hashicorp/http-echo"
        args = [
          "-text={\"version\": \"${VERSION}\", \"name\": \"${NOMAD_ALLOC_NAME}\"}",
          "-listen=:${NOMAD_PORT_http}"
        ]
      }

      resources {
        cpu = 20
        memory = 10
        network {
          port  "http"{}
        }
      }

      service {
        name = "stable-demo"
        port = "http"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.stable-demo.entryPoints=internal,external"
        ]
        canary_tags = [""]
      }
      service {
        name = "canary-demo"
        port = "http"

        canary_tags = [
          "traefik.enable=true",
          "traefik.http.routers.canary-demo.entryPoints=internal,external"
        ]
      }
      service {
        name = "demo"
        port = "http"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.demo.entryPoints=internal,external"
        ]
      }
    }
  }
}
