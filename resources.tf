# Provider Configuration for GitHub
# provider "github" {
#   token = var.github_token  # GitHub PAT with repo access
#   owner = var.github_owner  # Your GitHub username or organization
# }

# Key Vault Data Sources (3 Vaults for Different Environments)
data "azurerm_key_vault" "prod_vault" {
  name                = var.key_vault_name_prod
  resource_group_name = var.azure_resource_group
}

data "azurerm_key_vault" "stage_vault" {
  name                = var.key_vault_name_staging
  resource_group_name = var.azure_resource_group
}

data "azurerm_key_vault" "dev_vault" {
  name                = var.key_vault_name_dev
  resource_group_name = var.azure_resource_group
}

# GitLab Project and Variables Data Sources
data "gitlab_project" "project" {
  path_with_namespace = var.gitlab_project_path
}

data "gitlab_project_variables" "secrets" {
  project = data.gitlab_project.project.id
}

# GitHub Repository Data Source
data "github_repository" "repo" {
  full_name = "${var.github_owner}/${var.github_repo_name}"
}

# Create GitHub Environments
resource "github_repository_environment" "environments" {
  for_each = toset(["production", "staging", "development"])

  repository  = data.github_repository.repo.name
  environment = each.key
}

# Local Variables
locals {
  # Sanitize GitHub repo name for consistent naming
  repo_suffix = lower(replace(var.github_repo_name, "/[^a-zA-Z0-9-]/", "-"))

  # Map environment scopes to Key Vault IDs
  key_vaults = {
    "production"  = data.azurerm_key_vault.prod_vault.id
    "staging"     = data.azurerm_key_vault.stage_vault.id
    "development" = data.azurerm_key_vault.dev_vault.id
  }

  # Map GitLab environment scopes to GitHub environment names with aliases
  github_env_mapping = {
    "production"  = "production"
    "prod"        = "production"  # Alias for production
    "staging"     = "staging"
    "development" = "development"
    "dev"         = "development"  # Alias for development
  }

  # Masked secrets with environment prefix for uniqueness
  masked_secrets = {
    for v in data.gitlab_project_variables.secrets.variables :
    "${lower(coalesce(v.environment_scope, "development"))}-${v.key}" => v
    if v.masked
  }

  # Unmasked secrets with environment prefix for uniqueness, filtered for non-empty values
  unmasked_secrets = {
    for v in data.gitlab_project_variables.secrets.variables :
    "${lower(coalesce(v.environment_scope, "development"))}-${v.key}" => v
    if !v.masked && v.value != "" && v.value != null
  }
}

# Store Masked Variables in Azure Key Vault
resource "azurerm_key_vault_secret" "masked_secrets" {
  for_each = local.masked_secrets

  name         = "${local.repo_suffix}-${replace(replace(each.value.key, "_", "-"), "/[^a-zA-Z0-9-]/", "-")}"
  value        = each.value.value
  key_vault_id = lookup(local.key_vaults, element(split("-", each.key), 0), local.key_vaults["development"])
  content_type = var.github_repo_name
  tags = {
    environment = element(split("-", each.key), 0)
    repository  = local.repo_suffix
  }

  lifecycle {
    ignore_changes = [value]
  }
}

# Store Unmasked Variables in GitHub Environments
resource "github_actions_environment_variable" "unmasked_vars" {
  for_each = local.unmasked_secrets

  repository    = data.github_repository.repo.name
  environment   = try(local.github_env_mapping[element(split("-", each.key), 0)], "development")
  variable_name = each.value.key
  value         = each.value.value
  depends_on    = [github_repository_environment.environments]
}
