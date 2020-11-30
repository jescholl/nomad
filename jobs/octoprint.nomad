job "octoprint" {
  datacenters = ["dc1"]
  type        = "service"

  group "print" {
    count = 1

    vault {
      policies = ["pihole"]
    }

    task "server" {
      driver = "docker"

      env {
        # FIXME: this needs to be customized
        #CAMERA_DEV = "/dev/video0"
      }

      config {
        image = "octoprint/octoprint:1.4"

        volumes = [
        # FIXME: this needs to be customized
        # "/dev/ACM0:/dev/ACM0"
        ]
        mounts = [
          {
            target = "/octoprint"
            source = "octoprint"
            volume_options {
              driver_config {
                name = "pxd"
                options = {
                  size = "1G"
                  repl = "2"
                  shared = "true"
                }
              }
            }
          }
        ]
        port_map = {
          http = 80
        }
      }

      resources {
        network {
          port  "http" { to = 80 }
        }
      }

      service {
        name = "octoprint"
        port = "http"

        check {
          type = "http"
          path = "/api/version"
          interval = "30s"
          timeout = "2s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.octoprint.entryPoints=internal",
        ]
      }
    }
  }
}
