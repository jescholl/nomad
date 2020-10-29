job "prometheus" {
  datacenters = ["dc1"]
  type = "service"

  group "monitoring" {
    count = 1
    restart {
      attempts = 2
      interval = "30m"
      delay = "15s"
      mode = "fail"
    }
    ephemeral_disk {
      size = 300
    }

    task "prometheus" {
      template {
        change_mode = "noop"
        destination = "local/webserver_alert.yml"
        data = <<EOH
---
groups:
- name: prometheus_alerts
  rules:
  - alert: Webserver down
    expr: absent(up{job="webserver"})
    for: 10s
    labels:
      severity: critical
    annotations:
      description: "Our webserver is down."
EOH
      }

      template {
        change_mode = "noop"
        destination = "local/prometheus.yml"
        data = <<EOH
---
global:
  scrape_interval:     5s
  evaluation_interval: 5s

alerting:
  alertmanagers:
  - consul_sd_configs:
    - server: '{{ env "NOMAD_IP_prometheus_ui" }}:8501'
      services: ['alertmanager']
      scheme: https
      tls_config:
        ca_file: /vault_ca.crt

rule_files:
  - "webserver_alert.yml"

scrape_configs:

  - job_name: 'nomad_metrics'

    consul_sd_configs:
    - server: '{{ env "NOMAD_IP_prometheus_ui" }}:8501'
      services: ['nomad-client', 'nomad']
      scheme: https
      tls_config:
        ca_file: /vault_ca.crt

    relabel_configs:
    - source_labels: ['__meta_consul_tags']
      regex: '(.*)http(.*)'
      action: keep

    scrape_interval: 5s
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']

# Dynamically defined services from consul
{{- range $service := services -}}
  {{- range $tag := $service.Tags }}
    {{- if $tag | regexMatch "^prometheus.*=" }}
      {{- $tag := ($tag | regexReplaceAll "^prometheus." "") }}
      {{- $k := (index ($tag | split "=") 0 | replaceAll "." "/") }}
      {{- $v := index ($tag | split "=") 1 }}
      {{- scratch.MapSet $service.Name $k $v }}
    {{- end }}
  {{- end }}
  {{- if (scratch.Key $service.Name) }}
  - job_name: '{{ $service.Name }}'
    consul_sd_configs:
    - server: '{{ env "NOMAD_IP_prometheus_ui" }}:8501'
      services: ['{{ $service.Name }}']
      scheme: https
      tls_config:
        ca_file: /vault_ca.crt
{{ "# Dynamic configs from consul tags" | indent 4 }}
{{ scratch.Get $service.Name | explodeMap | toYAML | indent 4 }}
  {{- end }}
{{- end }}
EOH
      }
      driver = "docker"
      config {
        #image = "prom/prometheus:latest"
        image = "hashicorp/http-echo"
        args = [ "-text=foo"]
        volumes = [
          "local/webserver_alert.yml:/etc/prometheus/webserver_alert.yml",
          "local/prometheus.yml:/etc/prometheus/prometheus.yml",
          "/usr/local/share/ca-certificates/vault_CAs.crt:/vault_ca.crt",
        ]
        port_map {
          prometheus_ui = 9090
        }
      }
      resources {
        network {
          port "prometheus_ui" {}
        }
      }
      #service {
      #  name = "prometheus"
      #  tags = [
      #    "traefik.enable=true",
      #    "traefik.http.routers.prometheus.entryPoints=internal",
      #  ]

      #  port = "prometheus_ui"
      #  check {
      #    name     = "prometheus_ui port alive"
      #    type     = "http"
      #    path     = "/-/healthy"
      #    interval = "10s"
      #    timeout  = "2s"
      #  }
      #}
    }
  }
}
