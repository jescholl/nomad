job "smokeping" {
  datacenters = ["dc1"]
  type = "service"
  group "smokeping" {
    count = 1

    network {
      port "http" { to = 80 }
    }

    task "smokeping" {
      driver = "docker"
      config {
        image = "linuxserver/smokeping:latest"
        ports = ["http"]
        volumes = [
          "local/Targets:/config/Targets",
        ]

        mounts = [
          {
            target = "/config"
            source = "smokeping_config"
            readonly = false
            volume_options {
              no_copy = false
              driver_config {
                name = "pxd"
                options = {
                  size = "1G"
                  repl = "2"
                }
              }
            }
          },
          {
            target = "/data"
            source = "smokeping_data"
            readonly = false
            volume_options {
              no_copy = false
              driver_config {
                name = "pxd"
                options = {
                  size = "1G"
                  repl = "2"
                }
              }
            }
          },
        ]
      }

      resources {
        cpu    = 100
        memory = 256
      }

      service {
        name = "smokeping"
        port = "http"

        tags = [
          "traefik.http.middlewares.smokeping-add-prefix.addprefix.prefix=/smokeping/",
          "traefik.http.routers.smokeping.middlewares=smokeping-add-prefix@consulcatalog",
          "traefik.enable=true",
          "traefik.http.routers.smokeping.entryPoints=internal"
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "2s"
        }
      }

      template {
        destination = "local/Targets"
        data = <<EOF
*** Targets ***

probe = FPing

menu = Top
title = Network Latency Grapher
remark = Welcome to the SmokePing website of WORKS Company. \
         Here you will learn all about the latency of our network.

+ Internal
menu = Internal Devices
title = Internal Devices

++ Nates_Room_WAP
menu = Nates Room WAP
title = Nates Room WAP
host = natesroom.home.nosuchserver.net

++ Living_Room_WAP
menu = Living Room WAP
title = Living Room WAP
host = livingroom.home.nosuchserver.net

++ Theater_Room_WAP
menu = Theater Room WAP
title = Theater Room WAP
host = theaterroom.home.nosuchserver.net

++ USG
menu = USG
title = USG
host = fw.home.nosuchserver.net

++ Harmony_Hub
menu = Harmony Hub
title = Harmony Hub
host = harmonyhub.home.nosuchserver.net

++ Sense
menu = Sense
title = Sense
host = 192.168.10.84

++ Hue_Bridge
menu = Hue Bridge
title = Hue Bridge
host = 192.168.10.45

++ Smart_Things_Hub
menu = Smart Things Hub
title = Smart Things Hub
host = 192.168.10.97

++ MyQ_Internet_Gateway
menu = MyQ Internet Gateway
title = MyQ Internet Gateway
host = 192.168.10.53

+ InternetSites

menu = Internet Sites
title = Internet Sites

++ Facebook
menu = Facebook
title = Facebook
host = facebook.com

++ Youtube
menu = YouTube
title = YouTube
host = youtube.com

++ JupiterBroadcasting
menu = JupiterBroadcasting
title = JupiterBroadcasting
host = jupiterbroadcasting.com

++ GoogleSearch
menu = Google
title = google.com
host = google.com

++ linuxserverio
menu = linuxserver.io
title = linuxserver.io
host = linuxserver.io

+ Europe

menu = Europe
title = European Connectivity

++ Germany

menu = Germany
title = The Fatherland

+++ TelefonicaDE

menu = Telefonica DE
title = Telefonica DE
host = www.telefonica.de

++ Switzerland

menu = Switzerland
title = Switzerland

+++ CernIXP

menu = CernIXP
title = Cern Internet eXchange Point
host = cixp.web.cern.ch

+++ SBB

menu = SBB
title = SBB
host = www.sbb.ch/en

++ UK

menu = United Kingdom
title = United Kingdom

+++ CambridgeUni

menu = Cambridge
title = Cambridge
host = cam.ac.uk

+++ UEA

menu = UEA
title = UEA
host = www.uea.ac.uk

+ USA

menu = North America
title =North American Connectivity

++ MIT

menu = MIT
title = Massachusetts Institute of Technology Webserver
host = web.mit.edu

++ IU

menu = IU
title = Indiana University
host = www.indiana.edu

++ UCB

menu = U. C. Berkeley
title = U. C. Berkeley Webserver
host = www.berkley.edu

++ UCSD

menu = U. C. San Diego
title = U. C. San Diego Webserver
host = www.ucsd.edu

++ Sun

menu = Sun Microsystems
title = Sun Microsystems Webserver
host = www.oracle.com/us/sun

+ DNS
menu = DNS
title = DNS

++ GoogleDNS1
menu = Google DNS 1
title = Google DNS 8.8.8.8
host = 8.8.8.8

++ GoogleDNS2
menu = Google DNS 2
title = Google DNS 8.8.4.4
host = 8.8.4.4

++ OpenDNS1
menu = OpenDNS1
title = OpenDNS1
host = 208.67.222.222

++ OpenDNS2
menu = OpenDNS2
title = OpenDNS2
host = 208.67.220.220

++ CloudflareDNS1
menu = Cloudflare DNS 1
title = Cloudflare DNS 1.1.1.1
host = 1.1.1.1

++ CloudflareDNS2
menu = Cloudflare DNS 2
title = Cloudflare DNS 1.0.0.1
host = 1.0.0.1
EOF
      }
    }
  }
}
