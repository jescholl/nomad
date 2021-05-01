job "plex" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"

  vault {
    policies = ["plex"]
  }

  group "metrics" {
    count = 1
    network {
      port "prometheus" { to = "9594" }
    }

    task "exporter" {
      driver = "docker"
      config {
        ports = ["prometheus"]
        image = "granra/plex_exporter:v0.2.2"
        args = [ "--config-path", "/secrets/exporter.yml" ]
      }

      template {
        destination = "secrets/exporter.yml"
        data = <<-EOF
          {{ with secret "secret/app/plex/secrets" }}
          ---
          address: ":9594"
          logLevel: "debug"
          logFormat: "text"
          autoDiscover: false
          token: "{{ .Data.api_token }}"
          servers:
          - baseUrl: http://plex.nosuchserver.net:32400
          {{ end }}
        EOF
      }

      service {
        name = "plex-metrics"
        port = "prometheus"

        tags = [
          "prometheus.conf.metrics_path=/metrics"
        ]
      }
    }
  }

  group "plex" {
    count=1

    network {
      port "web" { static = 32400 }
      port "bonjour" { static = 5353 }
      # Plex companion
      port "roku" { static = 8324 }
      port "home_theater" { static = 3005 }
      # GDM
      port "gdm1" { static = 32412 }
      port "gdm2" { static = 32413 }
      port "gdm3" { static = 32414 }
      # DLNA
      port "dlna1" { static = 1900 }
      port "dlna2" { static = 32469 }
    }

    volume "plex_data" {
      type = "host"
      source = "plex_data"
    }

    volume "plex_config" {
      type = "host"
      source = "plex_config"
    }

    task "server" {
      driver = "docker"

      env {
        ADVERTISE_IP = "http://${attr.unique.network.ip-address}:${NOMAD_PORT_web}/"
        TZ = "America/Los_Angeles"
        ALLOWED_NETWORKS = "192.168.10.0/24"
      }

      config {
        hostname = "beast"
        image = "plexinc/pms-docker:plexpass"
        ports = ["web", "gdm1", "gdm2", "gdm3", "roku", "home_theater", "dlna1", "dlna2"]
        mount {
          type = "tmpfs"
          target = "/transcode"
          readonly = false
          tmpfs_options {
            size = 10 * 1024 * 1024 * 1024 # size in bytes
          }
        }
      }

      template {
        destination = "secrets/vault.env"
        env = true
        data = <<EOF
          {{ with secret "secret/app/plex/secrets" }}
          PLEX_CLAIM='{{ .Data.claim_token }}' # NOTE: Claim tokens are only valid for 4 minutes
          {{ end }}
        EOF
      }

      volume_mount {
        volume = "plex_data"
        destination = "/data"
      }

      volume_mount {
        volume = "plex_config"
        destination = "/config"
      }

      resources {
        cpu    = 500
        memory = 5 * 1024
      }

      service {
        name = "plex"
        port = "web"
        tags = [
          "traefik.enable=true",
          "traefik.tcp.routers.plex-remote.entryPoints=plex",
          "traefik.tcp.routers.plex-remote.rule=HostSNI(`*`)",
        ]
      }
    }
  }
}
