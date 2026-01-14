bao auth enable approle

cat > ./unas-prod-d1-agent-policy.hcl <<'EOF'
# Allow issuing certs from this PKI mount + role
path "pki/kube-prod-d1/apps-prod-d1/ICA2/issue/unas-prod-d1-agent" {
  capabilities = ["create", "update"]
}

# Let the agent renew its token
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Optional (nice for debugging)
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
EOF

bao policy write unas-prod-d1-agent-policy unas-prod-d1-agent-policy.hcl
rm unas-prod-d1-agent-policy.hcl

bao write pki/kube-prod-d1/apps-prod-d1/ICA2/roles/unas-prod-d1-agent \
  max_ttl="2160h" \
  allow_bare_domains=true \
  allow_subdomains=true \
  allow_wildcard_certificates=true \
  enforce_hostnames=true \
  allow_any_name=false \
  allowed_domains="mclacken.net" \
  organization="kube-prod-d1" \
  ou="McLacken net" \
  country="US" \
  province="California" \
  locality="San Francisco" 

bao write auth/approle/role/unas-prod-d1-agent \
  token_policies="unas-prod-d1-agent-policy" \
  token_ttl="24h" \
  token_max_ttl="72h" \
  token_bound_cidrs="10.42.0.0/16" \
  secret_id_bound_cidrs="10.42.0.0/16"

ROLE_ID="$(bao read -field=role_id auth/approle/role/unas-prod-d1-agent/role-id)"
SECRET_ID="$(bao write -f -field=secret_id auth/approle/role/unas-prod-d1-agent/secret-id)"

ssh root@unas-prod-d1.local-d1.mclacken.net "
set -e
mkdir -p /mnt/user/appdata/vault-agent/approle \
         /mnt/user/appdata/vault-agent/out \
         /mnt/user/appdata/vault-agent/config

umask 077
printf '%s' '$ROLE_ID'   > /mnt/user/appdata/vault-agent/approle/role-id
printf '%s' '$SECRET_ID' > /mnt/user/appdata/vault-agent/approle/secret-id

cat > /mnt/user/appdata/vault-agent/config/agent.hcl <<'EOF'
ui = true
listener \"tcp\" {
  address                               = \"[::]:8200\"
  tls_disable                           = \"true\"
  # tls_cert_file                         = \"/openbao/tls/tls.crt\"
  # tls_key_file                          = \"/openbao/tls/tls.key\"
  # tls_client_ca_file                    = \"/openbao/clientca/ca.crt\"
  # tls_require_and_verify_client_cert    = \"false\"
}

vault {
  address = \"https://openbao.kube-prod-d1.mclacken.net\"
  # If OpenBao uses a private CA, put the CA at /mnt/user/appdata/vault-agent/ca.pem
  # and uncomment:
  # ca_cert = \"/vault/ca.pem\"
}

auto_auth {
  method \"approle\" {
    config = {
      role_id_file_path                   = \"/vault/approle/role-id\"
      secret_id_file_path                 = \"/vault/approle/secret-id\"
      remove_secret_id_file_after_reading = false
    }
  }
}

cache {
  use_auto_auth_token = true
}

template {
  destination = \"/vault/out/unas-prod-d1_unraid_bundle.pem\"
  create_dest_dirs = true

  contents = <<EOH
{{- with secret \"pki/kube-prod-d1/apps-prod-d1/ICA2/issue/unas-prod-d1-agent\"
    \"common_name=unas-prod-d1.local-d1.mclacken.net\"
    \"alt_names=unas-prod-d1.local-d1.mclacken.net\"
    \"ip_sans=10.15.21.5\"
-}}
{{ .Data.certificate }}
{{- if .Data.ca_chain }}
{{- range .Data.ca_chain }}
{{ . }}
{{- end }}
{{- else if .Data.issuing_ca }}
{{ .Data.issuing_ca }}
{{- end }}

{{ .Data.private_key }}
{{- end }}
EOH
}
EOF

chown 100:1000 /mnt/user/appdata/vault-agent -R"

docker run -d \
  --name vault-agent-unraid \
  --restart unless-stopped \
  --cap-add IPC_LOCK \
  -v /mnt/user/appdata/vault-agent:/vault:rw \
  hashicorp/vault:latest \
  vault agent -config=/vault/config/agent.hcl -log-level=info