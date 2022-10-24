# Root NameSpace 접속 후 개별 NameSpace 작업 시, NameSpace 설정
locals {
  ns_name = var.vlt_namespace
}

# Cert와 Key가 stata file에 노출되므로, 가능하면 Terraform Enterprise를 사용할 것.

# PKI 시크릿 엔진 생성 
# Doc : https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/mount
resource "vault_mount" "pki_rootca" {
  namespace   = local.ns_name
  path        = "pki"
  type        = "pki"
  description = "Root CA용 PKI 시크릿 엔진"

  default_lease_ttl_seconds = "315360000" #10년, 1년 31,536,000초
  max_lease_ttl_seconds     = "315360000"

}

# Root CA 생성
# Doc : https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/pki_secret_backend_root_cert
## 01. Vault 상 Root CA 생성
resource "vault_pki_secret_backend_root_cert" "pki_rootca" {
  namespace            = local.ns_name
  depends_on           = [vault_mount.pki_rootca]
  backend              = vault_mount.pki_rootca.path
  type                 = "internal"
  common_name          = "Root CA"
  ttl                  = "315360000"
  format               = "pem"
  private_key_format   = "der"
  key_type             = "rsa"
  key_bits             = 4096
  exclude_cn_from_sans = true
  ou                   = "LinePlus Corp"
  organization         = "LinePlus Corp"
}

## 02. Root CA 파일 저장
# Doc : https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file
resource "local_file" "save_rootca" {
  content  = vault_pki_secret_backend_root_cert.pki_rootca.certificate
  filename = "${path.module}/crt/CA_cert.crt"
}


## 03. PKI Revocation Configuration
# Doc : https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/pki_secret_backend_config_urls
resource "vault_pki_secret_backend_config_urls" "pki_rootca" {
  namespace = local.ns_name
  backend   = vault_mount.pki_rootca.path
  issuing_certificates = [
    "http://127.0.0.1:8200/v1/pki/ca",
  ]
  crl_distribution_points = [
    "http://127.0.0.1:8200/v1/pki/crl",
  ]
}

## Intermediate CA 구성
# PKI 시크릿 엔진 생성 
# Doc : https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/mount
resource "vault_mount" "pki_int" {
  namespace   = local.ns_name
  path        = "pki_int"
  type        = "pki"
  description = "Intermediate CA용 PKI 시크릿 엔진"

  default_lease_ttl_seconds = "315360000" #10년, 1년 31,536,000초
  max_lease_ttl_seconds     = "315360000"

}

## Intermediate CA CSR 구성
# Doc: https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/pki_secret_backend_intermediate_cert_request
# Doc: https://developer.hashicorp.com/vault/api-docs/secret/pki#generate-intermediate-csr
/*
type (string: <required>) - Specifies the type of the intermediate to create. 
If exported, the private key will be returned in the response; if internal the private key will not be returned and cannot be retrieved later; 
if existing, we expect the key_ref parameter to use existing key material to create the CSR; kms is also supported: see below for more details. 
This parameter is part of the request URL.
*/

resource "vault_pki_secret_backend_intermediate_cert_request" "pki_int_csr" {
  namespace   = local.ns_name
  depends_on  = [vault_mount.pki_int]
  backend     = vault_mount.pki_int.path
  type        = "internal"
  common_name = "linepluscorp.com Intermediate Authority"
}

resource "local_file" "save_pki_int_csr" {
  content  = vault_pki_secret_backend_intermediate_cert_request.pki_int_csr.csr
  filename = "${path.module}/crt/pki_int_csr"
}


# Setting up Intermediate CA 
# Submit CA Cert to PKI Secret Backend
# Doc : https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/pki_secret_backend_root_sign_intermediate
resource "vault_pki_secret_backend_root_sign_intermediate" "sign_int" {
    namespace   = local.ns_name
  depends_on  = [vault_pki_secret_backend_intermediate_cert_request.pki_int_csr] 
  backend              = vault_mount.pki_rootca.path
  csr                  = vault_pki_secret_backend_intermediate_cert_request.pki_int_csr.csr
  common_name          = "linepluscorp.com Intermediate Authority"
#   exclude_cn_from_sans = true
#   ou                   = "SubUnit"
#   organization         = "SubOrg"
#   country              = "US"
#   locality             = "San Francisco"
#   province             = "CA"
#   revoke               = true
}


resource "local_file" "save_int_cert" {
  content  = vault_pki_secret_backend_root_sign_intermediate.sign_int.certificate
  filename = "${path.module}/crt/intermediate.cert.pem"
}

# Submit the CA Cert. to the PKI Secret Engine
# Doc : https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/pki_secret_backend_intermediate_set_signed


resource "vault_pki_secret_backend_intermediate_set_signed" "sign_int" {
     namespace   = local.ns_name
  depends_on  = [vault_pki_secret_backend_root_sign_intermediate.sign_int] 
  backend     = vault_mount.pki_int.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.sign_int.certificate
}

