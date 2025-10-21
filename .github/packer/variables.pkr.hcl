variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}
variable "resource_group" { default = "citrix-images" }
variable "location" { default = "eastus" }
variable "w11_image_name" { default = "w11-citrix-golden" }
variable "cc_image_name" { default = "winserver-cc-golden" }
variable "vm_size" { default = "Standard_D4s_v3" }
