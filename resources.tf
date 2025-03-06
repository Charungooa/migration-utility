# Data sources for Azure Key Vaults
data "azurerm_key_vault" "prod_vault" {
  name                = "prod-apollo-keyvault"
  resource_group_name = var.azure_resource_group
}

data "azurerm_key_vault" "stage_vault" {
  name                = "stage-apollo-keyvault"
  resource_group_name = var.azure_resource_group
}

# GitLab Project
data "gitlab_project" "project" {
  path_with_namespace = var.gitlab_project_path
}

# GitHub Repository (used for suffixes)
data "github_repository" "repo" {
  name = var.github_repo_name
}

# GitLab variables
data "gitlab_project_variables" "secrets" {
  project = data.gitlab_project.project.id
}

data "gitlab_project_variable" "variables" {
  for_each = toset([
    for v in data.gitlab_project_variables.secrets.variables : v.key
  ])
  project = data.gitlab_project.project.id
  key     = each.value
}

locals {
  # Sanitize the repository name once for consistent suffix
  repo_suffix = lower(replace(var.github_repo_name, "/[^a-zA-Z0-9-]/", "-"))

  # Transform all secrets by combining sanitized name with repository suffix
  transformed_secrets = {
    for key, value in data.gitlab_project_variable.variables :
    "${lower(replace(key, "/[^a-zA-Z0-9-]/", "-"))}-${local.repo_suffix}" => {
      original_key = key
      value        = value.value
      environment  = lower(lookup(value, "environment_scope", "stage"))
    }
  }
}

resource "azurerm_key_vault_secret" "all_secrets" {
  for_each = local.transformed_secrets

  name         = each.key
  value        = each.value.value
  content_type = var.github_repo_name

  key_vault_id = (
    each.value.environment == "prod"
    ? data.azurerm_key_vault.prod_vault.id
    : data.azurerm_key_vault.stage_vault.id
  )

  tags = {
    environment = each.value.environment
    repository  = local.repo_suffix
  }

  lifecycle {
    ignore_changes = [value]
  }
}