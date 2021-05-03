job "unifi" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"

  group "main" {
    count=1
    vault {
      policies = ["pki"]
    }

    constraint {
      attribute = "${meta.px-node}"
      value = "true"
    }

    network {
      port "cmdctrl" { to = 8080 }
      port "https" { to = 8443 }
      port "http" { to = 8880 }
      port "stun" { to = 3478 }
    }

    task "unifi" {
      driver = "docker"
      config {
        # NOTE: My WAPs will be going EOL and newer versions may not support them
        image = "jacobalberty/unifi:5.13.32"
        ports = ["cmdctrl", "https", "http", "stun"]
        volumes = [
          "secrets/certs:/unifi/cert",
          "local/default/config.gateway.json:/unifi/data/sites/default/config.gateway.json",
          "local/default/config.properties:/unifi/data/sites/default/config.properties"
        ]

        mount {
          target = "/unifi"
          source = "unifi"
          volume_options {
            driver_config {
              name = "pxd"
              options {
                size = "4G"
                repl = "2"
              }
            }
          }
        }
      }
      resources {
        cpu    = 500
        memory = 1024
      }
      service {
        name = "unifi-cmdctrl"
        port = "cmdctrl"
        tags = [
          "traefik.enable=true",
          "traefik.tcp.routers.unifi-cmdctrl.entryPoints=unifi_cmdctrl",
          "traefik.tcp.routers.unifi-cmdctrl.rule=HostSNI(`*`)",
        ]
      }
      service {
        name = "unifi-stun"
        port = "stun"
        tags = [
          "traefik.enable=true",
          "traefik.udp.routers.unifi-stun.entryPoints=unifi_stun",
        ]
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
          protocol = "https"
          path     = "/status"
          interval = "30s"
          timeout  = "2s"

          tls_skip_verify = false
        }
      }

      template {
        destination = "secrets/certs/cert.pem"
        data = <<EOF
{{ $ip_sans := printf "ip_sans=%s" (env "NOMAD_IP_https") }}
{{ with secret "pki_int/issue/nosuchserver-dot-net" "common_name=unifi.nosuchserver.net" $ip_sans }}
{{ .Data.certificate }}{{ end }}
EOF
      }

      template {
        destination = "secrets/certs/privkey.pem"
        data = <<EOF
{{ $ip_sans := printf "ip_sans=%s" (env "NOMAD_IP_https") }}
{{ with secret "pki_int/issue/nosuchserver-dot-net" "common_name=unifi.nosuchserver.net" $ip_sans }}
{{ .Data.private_key }}{{ end }}
EOF
      }

      template {
        destination = "secrets/certs/chain.pem"
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

      template {
        destination = "local/default/config.properties"
        change_mode = "noop"
        data = <<EOF
config.igd.enabled=true
config.system_cfg.1=sshd.auth.key.1.status=enabled
config.system_cfg.2=sshd.auth.key.1.value=ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQDokTfV3WD295LCy6Omhj/29+flG8MQgHvip8YfgiXGXTJxcuK3lsTHS6q8M/adFMkI7gnlXOm9EwFSeMwQ8VVeNVeKiAy4Lcoobm1WBu3bqSxUjREiWgmLlEENNj753gAASd4dXbVObgAMGAbq59BRSCNHX2EndHBift8pk1coXQ== jscholl@Jasons-MacBook-Pro-2.local

config.system_cfg.3=sshd.auth.key.1.type=ssh-rsa
EOF
      }
    }
  }
}
