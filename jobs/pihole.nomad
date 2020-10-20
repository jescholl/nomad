job "pihole" {
  datacenters = ["dc1"]

  group "dns" {
    count = 1

    update {
      max_parallel     = 1
      canary           = 1
      auto_revert      = true
      auto_promote     = true
    }

    task "server" {
      driver = "docker"
      shutdown_delay = "30s" # must be higher than traefik's refresh interval

      env {
        TZ = "America/Los_Angeles",
        VIRTUAL_HOST = "pihole.nosuchserver.net"
        #ServerIP = "192.168.10.6"
      }

      config {
        image = "pihole/pihole:latest"
        #cap_add = [
        #  "NET_ADMIN"
        #]
        args = [

        ]
        volumes = [
          "local/etc-pihole/:/etc/pihole/",
          "local/etc-dnsmasq.d/:/etc/dnsmasq.d/",
        ]
        port_map = {
          http = 80
          dns = 53
        }
      }

      resources {
        cpu = 200
        memory = 200
        network {
          port  "http" { to = 80 }
          port  "dns" { to = 53 }
        }
      }

      service {
        name = "pihole"
        port = "http"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.pihole.entryPoints=internal",
          #"traefik.http.middlewares.pihole-prefix.addprefix.prefix=/admin",
          #"traefik.http.middlewares.pihole-middleware2.headers.customrequestheaders.Host=pi.hole",
          #"traefik.http.routers.pihole.middlewares=pihole-prefix@consulcatalog",
        ]
      }
      service {
        name = "pihole-dns"
        port = "dns"

        tags = [
          "traefik.enable=true",
          "traefik.tcp.routers.pihole-dns.entryPoints=dns_tcp",
          "traefik.udp.routers.pihole-dns.entryPoints=dns_udp",
          "traefik.tcp.routers.pihole-dns.rule=HostSNI(`*`)",
        ]
      }
    }
  }
}
