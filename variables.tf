variable "rg_name" {
  default = "otp-rg"
}

variable "location" {
  default = "eastus"
}

variable "aks_name" {
  default = "otp-aks"
}
variable "subscription_id" {
  description = "Azure Subscription ID"
}

variable "argocd_namespace" {
  default = "argocd"
  description = "Namespace for Argo CD installation"
}
