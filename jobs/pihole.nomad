job "pihole" {
  datacenters = ["dc1"]
  type        = "service"
  priority = 90

  update {
    max_parallel     = 1
    canary           = 1
    auto_revert      = true
    auto_promote     = true
    min_healthy_time = "1m"
  }

  vault {
    policies = ["pihole"]
  }

  group "metrics" {
    count = 1

    network {
      port "prometheus" {}
    }

    task "exporter" {
      driver = "docker"
      config {
        ports = ["prometheus"]
        image = "ekofr/pihole-exporter:latest"
        volumes = [
          "/etc/ssl/certs:/etc/ssl/certs:ro"
        ]
      }

      resources {
        cpu = 10
        memory = 20
      }

      env {
        PIHOLE_PROTOCOL = "https"
        PIHOLE_HOSTNAME = "pihole.nosuchserver.net"
        PIHOLE_PORT = 443
        INTERVAL = "30s"
        PORT = NOMAD_PORT_prometheus
      }

      template {
        destination = "secrets/pihole.env"
        env = true
        data = <<EOF
          {{ with secret "secret/app/pihole/web" }}
          PIHOLE_PASSWORD='{{ .Data.password }}'
          {{ end }}
        EOF
      }

      service {
        name = "pihole-metrics"
        port = "prometheus"

        tags = [
          "prometheus.conf.metrics_path=/metrics"
        ]
      }
    }
  }

  group "main" {
    count = 1

    network {
      port  "http" { static = 80 }
      port  "dns" { static = 53 }
    }


    task "keepalived" {
      driver = "docker"
      shutdown_delay = "30s"

      env {
        KEEPALIVED_VIRTUAL_IPS = "192.168.10.7"
        KEEPALIVED_STATE = "BACKUP"
        KEEPALIVED_ROUTER_ID = 61
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

      resources {
        cpu = 10
        memory = 100
      }
    }

    task "pihole" {
      driver = "docker"
      shutdown_delay = "30s"

      env {
        TZ = "America/Los_Angeles"
        VIRTUAL_HOST = "pihole.nosuchserver.net"
        version = 2
      }

      config {
        network_mode = "host"
        image = "pihole/pihole:latest"

        volumes = [
          "local/etc-dnsmasq.d/:/etc/dnsmasq.d/"
        ]
        mount {
          target = "/etc/pihole/"
          source = "pihole"
          volume_options {
            driver_config {
              name = "pxd"
              options {
                size = "1G"
                repl = "2"
                shared = "true"
              }
            }
          }
        }
        ports = ["http", "dns"]
      }

      resources {
        cpu = 100
        memory = 200
      }

      service {
        name = "pihole"
        port = "http"

        check {
          type = "http"
          path = "/admin/"
          interval = "30s"
          timeout = "2s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.pihole.entryPoints=internal",
        ]
      }
      service {
        name = "pihole-dns"
        port = "dns"

        check {
          type = "script"
          command = "/usr/bin/dig"
          args = ["@127.0.0.1", "unifi.nosuchserver.net"]
          interval = "30s"
          timeout = "2s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.tcp.routers.pihole-dns.entryPoints=dns_tcp",
          "traefik.udp.routers.pihole-dns.entryPoints=dns_udp",
          "traefik.tcp.routers.pihole-dns.rule=HostSNI(`*`)",
        ]
      }

      template {
        destination = "secrets/pihole.env"
        env = true
        data = <<EOF
          {{ with secret "secret/app/pihole/web" }}
          WEBPASSWORD='{{ .Data.password }}'
          {{ end }}
        EOF
      }

      template {
        destination = "local/etc-dnsmasq.d/00-custom.conf"
        data = <<-EOF
          host-record=switch.home.nosuchserver.net,192.168.10.3
          {{ range nodes }}
          host-record={{ .Node }}.home.nosuchserver.net,{{ .Address }}{{ end }}
          address=/nosuchserver.net/192.168.10.6
          server=/consul/192.168.10.5#8600
          EOF
      }
    }
  }
}
