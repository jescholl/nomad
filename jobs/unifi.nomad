job "unifi" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"

  group "unifi" {
    count=1
    vault {
      policies = ["traefik"]
    }
    task "unifi" {
      driver = "docker"
      config {
        # NOTE: My WAPs will be going EOL and newer versions may not support them
        image = "jacobalberty/unifi:5.13.32"
        port_map = {
          cmdctrl = 8080
          https = 8443
          http = 8880
          stun = 3478
        }
        volumes = [
          "local/certs:/unifi/cert"
        ]
        mounts = [
          {
            target = "/unifi"
            source = "unifi"
            volume_options {
              driver_config {
                name = "pxd"
                options = {
                  size = "1G"
                  repl = "2"
                }
              }
            }
          }
        ]
      }
      resources {
        cpu    = 500
        memory = 1024
        network {
          port "cmdctrl" { to = 8080 }
          port "https" { to = 8443 }
          port "http" { to = 8880 }
          port "stun" { to = 3478 }
        }
      }
      service {
        name = "unifi"
        port = "https"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.unifi.entryPoints=internal",
          "traefik.http.services.unifi.loadbalancer.server.scheme=https",
        ]

        check {
          type     = "http"
          port     = "https"
          path     = "/status"
          interval = "30s"
          timeout  = "2s"

          tls_skip_verify = false
        }
      }

      template {
        destination = "local/certs/cert.pem"
        data = <<EOF
{{ $ip_sans := printf "ip_sans=%s" (env "NOMAD_IP_https") }}
{{ with secret "pki_int/issue/nosuchserver-dot-net" "common_name=unifi.nosuchserver.net" $ip_sans }}
{{ .Data.certificate }}{{ end }}
EOF
      }

      template {
        destination = "local/certs/privkey.pem"
        data = <<EOF
{{ $ip_sans := printf "ip_sans=%s" (env "NOMAD_IP_https") }}
{{ with secret "pki_int/issue/nosuchserver-dot-net" "common_name=unifi.nosuchserver.net" $ip_sans }}
{{ .Data.private_key }}{{ end }}
EOF
      }

      template {
        destination = "local/certs/chain.pem"
        data = <<EOF
{{ $ip_sans := printf "ip_sans=%s" (env "NOMAD_IP_https") }}
{{ with secret "pki_int/issue/nosuchserver-dot-net" "common_name=unifi.nosuchserver.net" $ip_sans }}
{{ .Data.issuing_ca }}{{ end }}
EOF
      }

      template {
        destination = "local/default/config.gateway.json"
        change_mode = "noop"
        data = <<EOF
{
  "service": {
    "dns": {
      "forwarding": {
        "options": [
          "host-record=switch.home.nosuchserver.net,192.168.10.3",
          "host-record=consuldns.home.nosuchserver.net,192.168.10.5",
          {{ range nodes }}
          "host-record={{ .Node }}.home.nosuchserver.net,{{ .Address }}",
          {{ end }}
          "address=/nosuchserver.net/192.168.10.6",
          "server=/consul/192.168.10.5#8600",
          "server=9.9.9.9",
          "server=8.8.8.8"
        ]
      }
    }
  }
}
EOF
      }
    }
  }
}
