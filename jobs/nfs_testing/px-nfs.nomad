job "px-nfs" {
  datacenters = ["dc1"]
  type        = "service"

  group "nfs" {
    count = 1

    network {
      port "fake-nfs" {}
    }

    task "server" {
      driver = "docker"

      config {
        image = "gcr.io/google_containers/pause:latest"

        mount {
          target = "/data"
          source = "px-nfs-test"
          volume_options {
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
      
      service {
        name = "px-nfs"
        port = "fake-nfs"
      }
    }
  }
}
