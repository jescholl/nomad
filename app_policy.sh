#!/bin/bash

app_policy() {
  app_name=$1

  cat | vault policy write "$app_name" - <<EOT
# key/value secrets
path "secret/app/$app_name/*"
{
  capabilities = ["read","list"]
}

path "secret/global/*"
{
  capabilities = ["read","list"]
}
EOT
}

app_policy plex
app_policy observium
app_policy pihole
app_policy alertmanager
