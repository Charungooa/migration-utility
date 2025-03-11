variable "gitlab_project_path" {
  description = "GitLab project path (namespace/project)"
  type        = string
}

variable "github_owner" {
  description = "GitHub username or organization name where repo exists"
  type        = string
}

variable "github_repo_name" {
  description = "Name of the GitHub repository"
  type        = string
}

variable "azure_resource_group" {
  description = "Name of existing Azure resource group containing the Key Vault"
  type        = string
  default     = "Backend-rg"
}

variable "key_vault_name" {
  description = "Name of existing Azure Key Vault"
  type        = string
  default     = "gitlabmigvault"
}

variable "azure_location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "gitlab_token" {
  description = "GitLab Personal Access Token for API access"
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "GitHub Personal Access Token"
  type        = string
  sensitive   = true
}

variable "AZURE_TENANT_ID" {
  description = "Azure AD Tenant ID"
  type        = string
}

variable "AZURE_CLIENT_OBJECT_ID" {
  description = "Object ID for Azure AD principal with Key Vault access"
  type        = string
}

variable "AZURE_CLIENT_ID" {
  type        = string
  description = "Azure AD Application client ID"
}

variable "AZURE_CLIENT_SECRET" {
  type        = string
  description = "Azure AD Application client secret"
  sensitive   = true
}

variable "AZURE_SUBSCRIPTION_ID" {
  type        = string
  description = "Azure subscription ID"
}

variable "key_vault_name_prod" {
  description = "Name of existing Azure Key Vault"
  type        = string
  default     = "gitlabmigvault"
}

variable "key_vault_name_dev" {
  description = "Name of existing Azure Key Vault"
  type        = string
  default     = "gitlabmigvault"
}

variable "key_vault_name_staging" {
  description = "Name of existing Azure Key Vault"
  type        = string
  default     = "null"
}