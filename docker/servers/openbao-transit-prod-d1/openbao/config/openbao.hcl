ui = true

disable_mlock = true

api_addr = "https://openbao.openbao-transit-prod-d1.mclacken.net:8200"
cluster_addr = "https://openbao.openbao-transit-prod-d1.mclacken.net:8201"

storage "raft" {
  path    = "/openbao/data"
  node_id = "openbao-transit-prod-d1"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"

  tls_cert_file = "/openbao/tls/server.crt"
  tls_key_file  = "/openbao/tls/server.key"

  tls_client_ca_file = "/openbao/tls/bootstrap-ca.crt"

  tls_require_and_verify_client_cert = true
}