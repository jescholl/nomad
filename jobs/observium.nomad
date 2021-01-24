job "observium" {
  datacenters = ["dc1"]
  type = "service"
  group "observium" {
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
        data = <<EOF
<?php

## Check http://www.observium.org/docs/config_options/ for documentation of possible settings

## It's recommended that settings are edited in the web interface at /settings/ on your observium installation.
## Authentication and Database settings must be hardcoded here because they need to work before you can reach the web-based configuration interface

// Database config ---  This MUST be configured
{{ with secret "secret/app/observium/mysql" }}
$_SERVER["SERVER_PORT"]  = '';
$config['db_extension'] = 'mysqli';
$config['db_host']      = '{{ env "NOMAD_IP_mysql_mysql" }}';
$config['db_port']      = '{{ env "NOMAD_PORT_mysql_mysql" }}';
$config['db_user']      = 'observium';
$config['db_pass']      = '{{ .Data.db_pass }}';
$config['db_name']      = 'observium';
{{ end }}

// Enable rrdcached
$config['rrdcached']    = "unix:/var/run/rrdcached.sock";

// Base directory
#$config['install_dir'] = "/opt/observium";

{{ with secret "secret/global/snmp" }}
// Default community list to use when adding/discovering
$config['snmp']['community'] = array("public");
$config['snmp']['version'] = "v3";
$config['snmp']['v3'][0]['authlevel'] = "authPriv";  // noAuthNoPriv | authNoPriv | authPriv
$config['snmp']['v3'][0]['authname'] = "{{ .Data.authname }}";  // User Name (required even for noAuthNoPriv)
$config['snmp']['v3'][0]['authpass'] = "{{ .Data.authpass }}";           // Auth Passphrase
$config['snmp']['v3'][0]['authalgo'] = "{{ .Data.authalgo }}";        // MD5 | SHA
$config['snmp']['v3'][0]['cryptopass'] = "{{ .Data.cryptopass }}";         // Privacy (Encryption) Passphrase
$config['snmp']['v3'][0]['cryptoalgo'] = "{{ .Data.cryptoalgo }}";      // AES | DES
{{ end }}

// Authentication Model
$config['auth_mechanism'] = "mysql";    // default, other options: ldap, http-auth, please see documentation for config help

// Enable alerter
// $config['poller-wrapper']['alerter'] = TRUE;

//$config['web_show_disabled'] = FALSE;    // Show or not disabled devices on major pages.

// Set up a default alerter (email to a single address)
//$config['email']['default']        = "user@your-domain";
//$config['email']['from']           = "Observium <observium@your-domain>";
//$config['email']['default_only']   = TRUE;

// End config.php

EOF
      }
    }
  }
}
