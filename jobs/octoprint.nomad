job "octoprint" {
  datacenters = ["dc1"]
  type        = "service"

  group "print" {
    count = 1

    constraint {
      attribute = "${meta.prusa_printer}"
      value = "true"
    }

    task "server" {
      driver = "docker"

      env {
        CAMERA_DEV = "/dev/video0"
        ENABLE_MJPG_STREAMER = "true"
      }

      config {
        image = "octoprint/octoprint:1.5"

          devices = [
            {
              host_path = "/dev/video0"
              container_path = "/dev/video0"
              cgroup_permissions = "rw"
            },
            {
              host_path = "/dev/ttyACM0"
              container_path = "/dev/ttyACM0"
              cgroup_permissions = "rw"
            }
          ]
        mounts = [
          {
            target = "/octoprint"
            source = "octoprint"
            volume_options {
              driver_config {
                name = "pxd"
                options = {
                  size = "10G"
                  repl = "2"
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
