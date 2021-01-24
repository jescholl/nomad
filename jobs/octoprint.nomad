job "octoprint" {
  datacenters = ["dc1"]
  type        = "service"

  group "print" {
    count = 1

    constraint {
      attribute = "${meta.prusa_printer}"
      value = "true"
    }

    network {
      port  "http" { to = 80 }
    }

    task "server" {
      driver = "docker"

      env {
        CAMERA_DEV = "/dev/video1"
        ENABLE_MJPG_STREAMER = "true"
        MJPG_STREAMER_INPUT = "-n -r 1280x1024"
      }

      config {
        image = "octoprint/octoprint:1.5.3"

        devices = [
          {
            host_path = "/dev/video1"
            container_path = "/dev/video1"
            cgroup_permissions = "rw"
          },
          {
            host_path = "/dev/ttyACM0"
            container_path = "/dev/ttyACM0"
            cgroup_permissions = "rw"
          }
        ]

        mount {
          target = "/octoprint"
          source = "octoprint"
          volume_options {
            driver_config {
              name = "pxd"
              options {
                size = "10G"
                repl = "2"
              }
            }
          }
        }
        ports = ["http"]
      }

      resources {
        memory = 1024
      }

      service {
        name = "octoprint"
        port = "http"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.octoprint.entryPoints=internal",
        ]
      }
    }
  }
}
