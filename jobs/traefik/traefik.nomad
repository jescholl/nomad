job "traefik" {
  datacenters = ["dc1"]
  type        = "service"
  priority = 60

  update {
    max_parallel = 1
    canary       = 1
    auto_revert  = true
    auto_promote = true
  }

  group "error-pages" {
    count = 1

    network {
      port "http" { to = 8080 }
    }

    task "error-pages" {
      driver = "docker"
      config {
        image = "tarampampam/error-pages:1.3.0"
        ports = ["http"]
      }
      resources {
        cpu    = 20
        memory = 10
      }
      service {
        name = "error-pages"
        port = "http"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.error-pages.entryPoints=internal,external",
          # use as "fallback" for any non-registered services (with priority below normal)
          "traefik.http.routers.error-pages.rule=HostRegexp(`{host:.+}`)",
          "traefik.http.routers.error-pages.priority=10",

          # Set intercept PUT/POST/PATCH/DELETE methods from external
          "traefik.http.routers.error-pages-external-method-filter.entryPoints=external",
          "traefik.http.routers.error-pages-external-method-filter.rule=Method(`PUT`, `POST`,`PATCH`, `DELETE`)",
          "traefik.http.routers.error-pages-external-method-filter.priority=100",
          "traefik.http.routers.error-pages-external-method-filter.service=error-pages@consulcatalog",

          # setup middleware for other services to use
          "traefik.http.middlewares.error-pages-middleware.errors.status=500-599",
          "traefik.http.middlewares.error-pages-middleware.errors.service=error-pages@consulcatalog",
          "traefik.http.middlewares.error-pages-middleware.errors.query=/{status}.html",
        ]

        check {
          type     = "http"
          path     = "/404.html"
          interval = "30s"
          timeout  = "2s"
        }
      }
    }
  }

  group "main" {
    count = 1
    vault {
      policies = ["traefik"]
    }

    network {
      port "http_internal" { static = 80 }
      port "internal" { static = 443 }
      port "http_external" { static = 9080 }
      port "external" { static = 9443 }

      port "dns" { static = 8053 }

      port "plex" { static = 32400 }

      port "unifi_stun" { static = 3478 }
      port "unifi_cmdctrl" { static = 8080 }

      port "minecraft" { static = 25565 }
      port "minecraft_rcon" { static = 25575 }

      port "prometheus" {}
    }

    task "keepalived" {
      driver = "docker"
      env {
        KEEPALIVED_VIRTUAL_IPS = "192.168.10.6"
        KEEPALIVED_STATE = "BACKUP"
        KEEPALIVED_UNICAST_PEERS = ""
      }

      config {
        image        = "osixia/keepalived:2.0.20"
        network_mode = "host"
        cap_add = [
          "NET_ADMIN",
          "NET_BROADCAST",
          "NET_RAW"
        ]
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v2.4"
        network_mode = "host"

        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
          "local/dynamic/traefik.toml:/etc/traefik/dynamic/traefik.toml",
          "/usr/local/share/ca-certificates/vault_CAs.crt:/vault_ca.crt"
        ]
        mount {
          type = "volume"
          target = "/etc/traefik/acme"
          source = "traefik_certs"
          volume_options {
            driver_config {
              name = "pxd"
              options {
                size = "1G"
                repl = "1"
                shared = "true"
              }
            }
          }
        }
      }

      resources {
        cpu    = 100
        memory = 128
      }

      service {
        name = "traefik"
        port = "internal"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.traefik.entryPoints=internal",
          "traefik.http.routers.traefik.service=api@internal",
        ]

        check {
          type     = "http"
          protocol = "https"
          tls_skip_verify = true
          # Fetching error-pages through traefik ensures the consulcatalog provider is working
          header   { Host = ["error-pages.nosuchserver.net"] }
          path     = "/404.html"
          interval = "30s"
          timeout  = "2s"
        }
      }

      service {
        name = "traefik-metrics"
        port = "prometheus"
        tags = [
          "prometheus.conf.metrics_path=/metrics"
        ]
      }

      template {
        destination = "local/traefik.env"
        env = true
        data = <<-EOF
          {{ with secret "secret/app/traefik/namecheap" }}
          NAMECHEAP_API_USER={{ .Data.username }}
          NAMECHEAP_API_KEY={{ .Data.api_key }}
          {{ end }}
          EOF
      }

      template {
        destination = "local/dynamic/traefik.toml"
        change_mode = "noop"
        left_delimiter = "{#"
        right_delimiter = "#}"
        data = file("dynamic.toml.ctpl")
      }

      template {
        destination = "local/traefik.toml"
        left_delimiter = "{#"
        right_delimiter = "#}"
        data = file("static.toml.ctpl")
      }
    }
  }
}
