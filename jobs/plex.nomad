job "plex" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"

  group "plex" {
    count=1
    vault {
      policies = ["plex"]
    }

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
        ADVERTISE_IP = "${attr.unique.network.ip-address}"
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
