# Data source for existing Azure Key Vault
data "azurerm_key_vault" "existing_vault" {
  name                = var.key_vault_name
  resource_group_name = var.azure_resource_group
}

# Fetch GitLab project
data "gitlab_project" "project" {
  path_with_namespace = var.gitlab_project_path
}

# Fetch all variables from GitLab project
data "gitlab_project_variables" "secrets" {
  project = data.gitlab_project.project.id
}

# Fetch individual variables for detailed access
data "gitlab_project_variable" "variables" {
  for_each = toset([
    for v in data.gitlab_project_variables.secrets.variables : v.key
  ])
  project = data.gitlab_project.project.id
  key     = each.value
}

# Process and classify variables (masked vs. unmasked)
locals {
  masked_variables = {
    for key, value in data.gitlab_project_variable.variables : key => value.value
    if value.masked  # Assume `masked` indicates sensitive secrets
  }
  unmasked_variables = {
    for key, value in data.gitlab_project_variable.variables : key => value.value
    if !value.masked  # Assume `!masked` indicates non-sensitive data
  }
}

# Store masked (sensitive) variables in Azure Key Vault
resource "azurerm_key_vault_secret" "masked_secrets" {
  for_each     = local.masked_variables
  name         = replace(each.key, "_", "-")  # Sanitize key for Key Vault (no underscores)
  value        = each.value
  key_vault_id = data.azurerm_key_vault.existing_vault.id
}

# Store unmasked (non-sensitive) variables in GitHub repository variables
resource "github_actions_variable" "unmasked_variables" {
  for_each    = local.unmasked_variables
  repository  = var.github_repo_name
  variable_name = each.key
  value       = each.value
}
