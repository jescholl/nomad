job "observium" {
  datacenters = ["dc1"]
  type = "service"
  group "main" {
    count = 1

    vault {
      policies = ["observium"]
    }

    network {
      port "mysql" { to = 3306 }
      port "http" { to = 8000 }
    }

    task "mysql" {
      driver = "docker"
      env {
        TZ = "America/Los_Angeles"
        MYSQL_ONETIME_PASSWORD = "true"
        MYSQL_RANDOM_ROOT_PASSWORD = "true"
        MYSQL_USER = "observium"
        MYSQL_DATABASE = "observium"
      }

      config {
        image = "mysql:8"

        args = [
          "--default-authentication-plugin=mysql_native_password"
        ]
        ports = ["mysql"]
        volumes = [
          "name=observium_mysql,size=1G,repl=2:/var/lib/mysql",
        ]
      }

      resources {
        cpu = 100
        memory = 1024
      }

      template {
        destination = "secrets/vault.env"
        env = true
        data = <<EOF
          {{ with secret "secret/app/observium/mysql" }}
          MYSQL_PASSWORD='{{ .Data.db_pass }}'
          {{ end }}
          EOF
      }
    }

    task "observium" {
      driver = "docker"
      config {
        image = "jescholl/observium:latest"
        ports = ["http"]
        volumes = [
          "local/config.php:/config/config.php",
        ]
        mount {
          target = "/opt/observium/html"
          source = "observium_html"
          readonly = false
          volume_options {
            no_copy = false
            driver_config {
              name = "pxd"
              options {
                size = "1G"
                repl = "1"
              }
            }
          }
        }

        mount  {
          target = "/opt/observium/rrd"
          source = "observium_rrd"
          readonly = false
          volume_options {
            no_copy = false
            driver_config {
              name = "pxd"
              options {
                size = "5G"
                repl = "2"
              }
            }
          }
        }

        mount {
          target = "/opt/observium/logs"
          source = "observium_logs"
          readonly = false
          volume_options {
            no_copy = false
            driver_config {
              name = "pxd"
              options {
                size = "1G"
                repl = "1"
              }
            }
          }
        }
      }

      service {
        name = "observium"
        port = "http"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.observium.entryPoints=internal"
        ]


        check {
          type     = "http"
          path     = "/robots.txt"
          interval = "30s"
          timeout  = "2s"
        }
      }


      template {
        destination = "local/config.php"
        data = file("config.php.ctpl")
      }
    }
  }
}
