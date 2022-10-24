## Create a Role on an OKI Secret Backend for Vault
# Doc : https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/pki_secret_backend_role

resource "vault_pki_secret_backend_role" "role" {
 namespace = local.ns_name
  backend          = vault_mount.pki_int.path
  name             = "linepluscorp-dot-com"
  ttl              = 315000000
  allow_ip_sans    = true
  key_type         = "rsa"
  key_bits         = 4096
  allowed_domains  = ["linepluscorp.com","linecorp.com", "line.com","lineplus.com"]
  allow_subdomains = true
}

## Generate a Certificate from PKI Secret Backend
# Doc : https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/pki_secret_backend_cert
resource "vault_pki_secret_backend_cert" "app" {
    namespace = local.ns_name
  depends_on = [vault_pki_secret_backend_role.role]

  backend = vault_mount.pki_int.path
  name = vault_pki_secret_backend_role.role.name

  common_name = "vlt.linecorp.com"
}


resource "local_file" "save_leaf_cert" {
  content  = vault_pki_secret_backend_cert.app.certificate
  filename = "${path.module}/crt/leaf.crt"
}

resource "local_file" "save_leaf_key" {
  content  = vault_pki_secret_backend_cert.app.private_key
  filename = "${path.module}/crt/leaf.key"
}