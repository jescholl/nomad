job "prometheus" {
  datacenters = ["dc1"]
  type = "service"

  group "prometheus" {
    count = 1

    restart {
      attempts = 2
      interval = "30m"
      delay = "15s"
      mode = "fail"
    }

    network {
      port "web" { to = 9090 }
    }

    task "prometheus" {
      driver = "docker"
      config {
        ports = ["web"]
        image = "prom/prometheus:latest"
        mount {
          type = "bind"
          target = "/etc/prometheus/"
          source = "local"
        }
      }
      service {
        name = "prometheus"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.prometheus.entryPoints=internal",
        ]

        port = "web"

        check {
          type     = "http"
          path     = "/-/healthy"
          interval = "30s"
          timeout  = "2s"
        }
      }

      artifact {
        source = "https://active.vault.service.consul:8200/v1/pki/ca/pem"
        mode = "file"
        destination = "local/vault_ca.crt"
      }

      template {
        change_mode = "signal"
        change_signal = "SIGHUP"
        destination = "local/dynamic_alerts.yml"
        data = <<EOH
---
groups: 
{{ range ls "config/prometheus/alerts" }}
- name: {{ .Key }}
{{ .Value | indent 2 }}
{{ end }}
EOH
      }

      template {
        change_mode = "signal"
        change_signal = "SIGHUP"
        destination = "local/prometheus.yml"
        data = <<EOH
---
global:
  scrape_interval:     5s
  evaluation_interval: 5s

alerting:
  alertmanagers:
  - consul_sd_configs:
    - server: '{{ env "NOMAD_IP_web" }}:8501'
      services: ['alertmanager']
      scheme: https
      tls_config:
        ca_file: /etc/prometheus/vault_ca.crt

rule_files:
  - "dynamic_alerts.yml"

scrape_configs:
  - job_name: 'nomad_metrics'
    consul_sd_configs:
    - server: '{{ env "NOMAD_IP_web" }}:8501'
      services: ['nomad-client', 'nomad']
      scheme: https
      tls_config:
        ca_file: /etc/prometheus/vault_ca.crt

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
    {{- if $tag | regexMatch "^prometheus\\.conf\\..*=" }}
      {{- $tag := ($tag | regexReplaceAll "^prometheus\\.conf\\." "") }}
      {{- $k := (index ($tag | split "=") 0 | replaceAll "." "/") }}
      {{- $v := index ($tag | split "=") 1 }}
      {{- scratch.MapSet $service.Name $k $v }}
    {{- end }}
  {{- end }}
  {{- if (scratch.Key $service.Name) }}
  - job_name: '{{ $service.Name }}'
    consul_sd_configs:
    - server: '{{ env "NOMAD_IP_web" }}:8501'
      services: ['{{ $service.Name }}']
      scheme: https
      tls_config:
        ca_file: /etc/prometheus/vault_ca.crt
{{ "# Dynamic configs from consul tags" | indent 4 }}
# {{ scratch.Get $service.Name }}
{{ scratch.Get $service.Name | explodeMap | toYAML | indent 4 }}
  {{ end }}
{{- end }}
EOH
      }
    }
  }
}
