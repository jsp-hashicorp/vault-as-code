variable "login_username" {
  description = "Vault 서버 접속 시 사용할 Username"
}

variable "login_password" {
  description = "Vault 서버 접속 시 사용 계정의 비밀번호"
}

variable "vlt_addr" {
  description = "사용할 Vault 서버 API ADDR"
}

variable "vlt_namespace" {
  description = "작업 시 사용할 네임스페이스 명"
}