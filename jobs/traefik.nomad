job "traefik" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"

  #update {
  #  max_parallel = 1
  #  canary = 1
  #}


  group "error-pages" {
    count=1
    task "error-pages" {
      driver = "docker"
      config {
        image = "tarampampam/error-pages:1.3.0"
        port_map = {
          http = 8080
        }
      }
      resources {
        cpu    = 20
        memory = 10

        network {
          port "http" { to = 8080 }
        }
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
          # setup middleware for other services to use
          "traefik.http.middlewares.error-pages-middleware.errors.status=400-599",
          "traefik.http.middlewares.error-pages-middleware.errors.service=error-pages@consulcatalog",
          "traefik.http.middlewares.error-pages-middleware.errors.query=/{status}.html",
        ]

        check {
          type     = "tcp"
          port     = "http"
          interval = "30s"
          timeout  = "2s"
        }
      }
    }
  }

  group "traefik" {
    count = 1
    vault {
      policies = ["traefik"]
    }

    task "keepalived" {
      env = {
        KEEPALIVED_VIRTUAL_IPS = "192.168.10.6"
        KEEPALIVED_STATE = "BACKUP"
        KEEPALIVED_UNICAST_PEERS = ""
      }

      driver = "docker"

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
        image        = "traefik:v2.3"
        network_mode = "host"

        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
          "local/dynamic/traefik.toml:/etc/traefik/dynamic/traefik.toml",
        ]
        mounts = [
          {
            target = "/etc/traefik/acme"
            source = "traefik_certs"
            volume_options {
              driver_config {
                name = "pxd"
                options = {
                  size = "1G"
                  repl = "1"
                }
              }
            }
          }
        ]
      }

      resources {
        cpu    = 100
        memory = 128

        network {
          port "http_internal" { static = 80 }
          port "internal" { static = 443 }
          port "http_external" { static = 9080 }
          port "external" { static = 9443 }
        }
      }

      template {
        destination = "local/traefik.env"
        env = true
        data = <<EOF
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
        data = <<EOF
# Dynamic Configuration

# Whitelist assigned to "internal" endpoint
[http.middlewares.internal-whitelist.ipWhiteList]
    sourceRange = ["192.168.10.0/24"]

# Manually define the traefik api/dashboard service so it can be properly secured (insecure=false)
[http.routers.dashboard]
    rule = "Host(`traefik.nosuchserver.net`)"
    service = "api@internal"
    entryPoints = ["internal"]

# Manually add services that are difficult to add dynamically
[http.routers.consul]
    rule = "Host(`consul.nosuchserver.net`)"
    service = "consul@file"
    entryPoints = ["internal"]

[http.routers.nomad]
    rule = "Host(`nomad.nosuchserver.net`)"
    service = "nomad@file"
    entryPoints = ["internal"]

[http.services]
    [http.services.nomad.loadBalancer]
        {# range service "http.nomad" #}
        [[http.services.nomad.loadBalancer.servers]]
            url = "http://{# .Address #}:{# .Port #}"
        {# end #}
  
    [http.services.consul.loadBalancer]
        [[http.services.consul.loadBalancer.servers]]
            url = "http://127.0.0.1:8500"
EOF
      }

      template {
        destination = "local/traefik.toml"
        left_delimiter = "{#"
        right_delimiter = "#}"
        data = <<EOF
{# with secret "secret/app/traefik/traefik" #}
[entryPoints]
    # redirect http->https on external
    [entryPoints.http_external]
        address = ":{# env "NOMAD_PORT_http_external" #}"
        [entryPoints.http_external.http.redirections.entryPoint]
            to = "external"

    # redirect http->https on internal
    [entryPoints.http_internal]
        address = ":{# env "NOMAD_PORT_http_internal" #}"
        [entryPoints.http_internal.http]
            middlewares = ["internal-whitelist@file"]
            [entryPoints.http_internal.http.redirections.entryPoint]
                to = "internal"

    [entryPoints.external]
        address = ":{# env "NOMAD_PORT_external" #}"
        [entryPoints.external.http]
            middlewares = ["error-pages-middleware@consulcatalog"]
        [entryPoints.external.http.tls]
            certResolver = "nosuchserver"
            [[entryPoints.external.http.tls.domains]]
                main = "nosuchserver.net"
                sans = ["*.nosuchserver.net"]

    [entryPoints.internal]
        address = ":{# env "NOMAD_PORT_internal" #}"
        [entryPoints.internal.http]
            middlewares = ["internal-whitelist@file", "error-pages-middleware@consulcatalog"]
            [entryPoints.internal.http.tls]
                certResolver = "nosuchserver"
                [[entryPoints.internal.http.tls.domains]]
                    main = "nosuchserver.net"
                    sans = ["*.nosuchserver.net"]

[certificatesResolvers.nosuchserver.acme]
    #caServer = "https://acme-staging-v02.api.letsencrypt.org/directory"
    email    = "jason.e.scholl@gmail.com"
    storage  = "/etc/traefik/acme/acme.json"
    [certificatesResolvers.nosuchserver.acme.dnsChallenge]
        provider = "namecheap"
        resolvers = ["8.8.8.8:53", "1.1.1.1:53", "9.9.9.9:53"]

[api]
    dashboard = true
 
[pilot]
    token = "{# .Data.pilot_token #}"

[providers]
    # Enable the file provider to define routers / middlewares / services in file
    [providers.file]
        directory = "/etc/traefik/dynamic"
  
    # Enable Consul Catalog configuration backend.
    [providers.consulCatalog]
        exposedByDefault = false
        prefix           = "traefik"
        defaultRule      = "Host(`{{ .Name }}.nosuchserver.net`)"
    
        [providers.consulCatalog.endpoint]
            address = "127.0.0.1:8500"
            scheme  = "http"

[log]
    level = "INFO"
{# end #}
EOF

      }
    }
  }
}
