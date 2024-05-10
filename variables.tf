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

variable "spot_instance_above_market_percentage" {
  type        = number
  description = "the above market price value in percentage you're willing to go"
  default     = 3
}

variable "instance_type" {
  type        = string
  description = "type of instance you want to run"
  default     = "t2.micro"
}
