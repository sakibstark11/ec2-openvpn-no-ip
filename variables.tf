variable "prefix" {
  type        = string
  description = "will be added where applicable"
}

variable "noip_username" {
  type        = string
  description = "user name for no ip"
  sensitive   = true
}

variable "noip_password" {
  type        = string
  description = "password for no ip"
  sensitive   = true
}

variable "noip_domain" {
  type        = string
  description = "domain to use to register with noip"
}

variable "public_key" {
  type        = string
  description = "to use for SSH access"
  sensitive   = true
}

variable "openvpn_script" {
  type        = string
  description = "openvpn script to fetch"
  default     = "https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh"
}
