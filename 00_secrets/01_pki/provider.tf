terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.8.0"
    }
  }

  required_version = "> 1.2.8"
}

provider "vault" {
  address = var.vlt_addr

  auth_login {
    path = "auth/userpass/login/${var.login_username}"
    # namespace = "admin/" # Namespace별 로그인 시 설정
    parameters = {
      password = var.login_password
    }
  }
}