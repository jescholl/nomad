job "alertmanager" {
  datacenters = ["dc1"]
  type = "service"

  vault {
    policies = ["alertmanager"]
  }

  group "alerting" {
    network {
      port "web" { to = 9093 }
    }

    restart {
      attempts = 2
      interval = "30m"
      delay = "15s"
      mode = "fail"
    }

    task "alertmanager" {
      driver = "docker"

      config {
        image = "prom/alertmanager:latest"
        ports = ["web"]
        args = [
          "--config.file=/secrets/alertmanager.yml",
          "--storage.path=/alertmanager",
          "--web.external-url=https://alertmanager.nosuchserver.net"
        ]
      }

      template {
        destination = "secrets/alertmanager.yml"
        data = <<-EOF
          global:
            slack_api_url: {{ with secret "secret/app/alertmanager/secrets" }}{{ .Data.slack_hook }}{{ end }}
          inhibit_rules:
          - equal:
            - alertname
            source_match:
              severity: critical
            target_match:
              severity: warning
          receivers:
          - name: default-receiver
            slack_configs:
            - channel: "#jason-notifications"
              send_resolved: true
          route:
            group_by:
            - job
            group_interval: 5m
            group_wait: 30s
            receiver: default-receiver
            repeat_interval: 3h
            routes: []
        EOF
      }

      service {
        name = "alertmanager"
        port = "web"

        check {
          name     = "alertmanager_ui port alive"
          type     = "http"
          path     = "/-/healthy"
          interval = "10s"
          timeout  = "2s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.alertmanager.entryPoints=internal",
          "prometheus.conf.metrics_path=/metrics",
        ]
      }
    }
  }
}
