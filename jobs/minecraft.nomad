locals {
  level = "world" #default = "world"
  mods = [
    #"https://media.forgecdn.net/files/3276/18/inventorypets-1.16.5-2.0.14.jar"
    #"https://github.com/sladkoff/minecraft-prometheus-exporter/releases/download/v2.4.0/minecraft-prometheus-exporter-2.4.0.jar"
  ]

  mods_split_urls = [ for mod_url in local.mods: split("/", mod_url) ]
  mods_filenames = [ for split_url in local.mods_split_urls: element(split_url, length(split_url) -1) ]
  type = length(local.mods) > 0 ? "BUKKIT" : "VANILLA"
  #motd = "${local.type} server - Mods: ${join(",", local.mods_filenames)}"
  motd = "${local.type} server - Mods: ${join(",", [ for mod in local.mods_filenames: split("-", mod)[0] ])}"
}
job "minecraft" {
  datacenters = ["dc1"]
  type        = "service"

  group "main" {
    count = 1

    network {
      port  "minecraft" { to = 25565 }
      port  "rcon" { to = 25575 }
      port  "jmx" { to = 7091 }
      port  "prometheus" { to = 9225 }
    }

    volume "minecraft" {
      type = "host"
      source = "minecraft"
    }

    task "minecraft" {
      driver = "docker"

      env {
        EULA = "true"
        MEMORY = "4G"
        WHITELIST = "CheesierCoast81,freedelahoya81,CloneID653,LittleClone"
        OVERRIDE_WHITELIST = "true"
        #OPS = "CheesierCoast81,freedelahoya81,CloneID653,LittleClone"
        ALLOW_FLIGHT = "true"
        TZ = "America/Los_Angeles"
        ENABLE_JMX = "true"
        JMX_HOST = "${attr.unique.network.ip-address}"
        OVERRIDE_SERVER_PROPERTIES = "true"

        # MODS
        REMOVE_OLD_MODS = "true"
        LEVEL = local.level
        MOTD = local.motd
        #MOTD = "Forge-modded server - Mod list: inventory-pets"
        MODS = join(",", local.mods)
        TYPE = local.type

        #VERSION = "LATEST"
        #VERSION = "1.7.9"

        # Defaults
        #DIFFICULTY = "easy"
      }

      config {
        image = "itzg/minecraft-server:2021.15.0-java16-openj9"

        #mount {
        #  target = "/data"
        #  source = "minecraft"
        #  volume_options {
        #    driver_config {
        #      name = "pxd"
        #      options {
        #        size = "10G"
        #        repl = "2"
        #      }
        #    }
        #  }
        #}
        ports = ["minecraft", "rcon", "prometheus"]
      }

      volume_mount {
        volume = "minecraft"
        destination = "/data"
      }

      resources {
        memory = 4608
        cpu = 7000
      }

      service {
        name = "minecraft"
        port = "minecraft"

        tags = [
          "traefik.enable=true",
          "traefik.tcp.routers.minecraft.entryPoints=minecraft",
          "traefik.tcp.routers.minecraft.rule=HostSNI(`*`)",
        ]
      }

      service {
        name = "minecraft-metrics"
        port = "prometheus"
        tags = [
          "prometheus.conf.metrics_path=/metrics"
        ]
      }

      service {
        name = "minecraft-rcon"
        port = "rcon"

        tags = [
          "traefik.enable=true",
          "traefik.tcp.routers.minecraft_rcon.entryPoints=minecraft_rcon",
          "traefik.tcp.routers.minecraft_rcon.rule=HostSNI(`*`)",
        ]
      }
    }
  }
}
