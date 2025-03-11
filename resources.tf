#
# Key Vault Data Sources (3 Vaults)
#
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

#
# GitLab Project & Variables
#
data "gitlab_project" "project" {
  path_with_namespace = var.gitlab_project_path
}

data "gitlab_project_variables" "secrets" {
  project = data.gitlab_project.project.id
}

#
# GitHub Repository (used for naming suffix)
#
data "github_repository" "repo" {
  name = var.github_repo_name
}

#
# Step 1: Locals
#
locals {
  # Sanitize the GitHub repo name, replacing underscores and other invalid characters with dashes
  repo_suffix = lower(replace(replace(var.github_repo_name, "_", "-"), "/[^a-zA-Z0-9-]/", "-"))

  # Build a map of secrets in one pass from GitLab variables
  transformed_secrets = {
    for v in data.gitlab_project_variables.secrets.variables :
    format(
      "%s-%s-%s",
      lower(replace(replace(v.key, "_", "-"), "/[^a-zA-Z0-9-]/", "-")),  # Replace underscores first, then other invalid characters
      length(v.environment_scope) > 0
        ? lower(replace(replace(v.environment_scope, "_", "-"), "/[^a-zA-Z0-9-]/", "-"))
        : "stage",
      local.repo_suffix
    ) => {
      original_key = v.key
      value        = v.value
      environment  = (
        length(v.environment_scope) > 0
        ? lower(replace(replace(v.environment_scope, "_", "-"), "/[^a-zA-Z0-9-]/", "-"))
        : "stage"
      )
    }
  }
}

#
# Step 2: Create Key Vault Secrets
#
resource "azurerm_key_vault_secret" "all_secrets" {
  for_each = local.transformed_secrets

  name  = each.key
  value = each.value.value

  # Route to correct vault purely by the GitLab environment scope
  key_vault_id = (
    each.value.environment == "production" ? data.azurerm_key_vault.prod_vault.id :
    each.value.environment == "staging" ? data.azurerm_key_vault.stage_vault.id :
    data.azurerm_key_vault.dev_vault.id
  )

  # content_type: environment derived from the secret's name + the repo name
  content_type = format(
    "%s-%s",
    can(regex("prod", lower(each.key))) ? "prod" :
    can(regex("uat", lower(each.key))) ? "uat" :
    can(regex("dev", lower(each.key))) ? "dev" :
    "unknown",
    local.repo_suffix
  )

  tags = {
    environment = each.value.environment
    repository  = local.repo_suffix
  }

  lifecycle {
    ignore_changes = [value]
  }
}