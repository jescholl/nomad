job "portworx-dev" {
  type        = "service"
  datacenters = ["dc1"]

  group "portworx" {
    count = 3

    constraint {
      operator  = "distinct_hosts"
      value     = "true"
    }

    constraint {
      attribute = "${meta.px-node}"
      operator = "="
      value = "true"
    }

    # restart policy for failed portworx tasks
    restart {
      attempts = 3
      delay    = "30s"
      interval = "5m"
      mode     = "fail"
    }

    # how to handle upgrades of portworx instances
    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
      auto_revert      = true
      canary           = 0
      stagger          = "30s"
    }

    task "px-dev-node" {
      driver = "docker"
      kill_timeout = "120s"   # allow portworx 2 min to gracefully shut down
      kill_signal = "SIGTERM" # use SIGTERM to shut down the nodes

      # consul service check for portworx instances
      service {
        name = "portworx-dev"
        check {
          port     = "portworx"
          type     = "http"
          path     = "/status"
          interval = "10s"
          timeout  = "2s"
        }
      }

      # setup environment variables for px-nodes
      env {
        "AUTO_NODE_RECOVERY_TIMEOUT_IN_SECS" = "1500"
        "PX_TEMPLATE_VERSION"                = "V4"
       }

      # container config
      config {
        image        = "portworx/px-dev:2.1.1"
        network_mode = "host"
        ipc_mode = "host"
        privileged = true

        # configure your parameters below
        # do not remove the last parameter (needed for health check)
        args = [
            "-c", "px-dev",
            "-a", "-A",
            "-k", "consul://127.0.0.1:8500",
        ]

        volumes = [
            "/var/run/docker/plugins:/var/run/docker/plugins",
            "/var/lib/osd:/var/lib/osd:shared",
            "/dev:/dev",
            "/etc/pwx:/etc/pwx",
            "/opt/pwx/bin:/export_bin",
            "/var/run/docker.sock:/var/run/docker.sock",
            "/var/cores:/var/cores",
            "/usr/src:/usr/src",
        ]
      }

      # resource config
      resources {
        cpu    = 1024
        memory = 2048

        network {
          port "portworx" {
            static = "9001"
          }
        }
      }
    }
  }
}
