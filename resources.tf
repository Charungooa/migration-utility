# Data sources for existing Azure Key Vaults
data "azurerm_key_vault" "prod_vault" {
  name                = "prod-apollo-keyvault"
  resource_group_name = var.azure_resource_group
}

data "azurerm_key_vault" "stage_vault" {
  name                = "stage-apollo-keyvault"
  resource_group_name = var.azure_resource_group
}

# Fetch all existing secrets from both Azure Key Vaults
data "azurerm_key_vault_secrets" "prod_existing_secrets" {
  key_vault_id = data.azurerm_key_vault.prod_vault.id
}

data "azurerm_key_vault_secrets" "stage_existing_secrets" {
  key_vault_id = data.azurerm_key_vault.stage_vault.id
}

# Fetch GitLab project details
data "gitlab_project" "project" {
  path_with_namespace = var.gitlab_project_path
}

# Fetch all variables from GitLab project
data "gitlab_project_variables" "secrets" {
  project = data.gitlab_project.project.id
}

# Fetch individual variables and their environment
data "gitlab_project_variable" "variables" {
  for_each = toset([
    for v in data.gitlab_project_variables.secrets.variables : v.key
  ])
  project = data.gitlab_project.project.id
  key     = each.value
}

# Extract existing secret names from both Key Vaults (converted to valid format)
locals {
  existing_secrets = toset(
    concat(
      [for s in data.azurerm_key_vault_secrets.prod_existing_secrets.names : lower(replace(s, "[^a-zA-Z0-9-]", "-"))],
      [for s in data.azurerm_key_vault_secrets.stage_existing_secrets.names : lower(replace(s, "[^a-zA-Z0-9-]", "-"))]
    )
  )

  # Process all variables, replacing underscores and ensuring uniqueness
  all_variables = {
    for key, value in data.gitlab_project_variable.variables :
    (
      contains(local.existing_secrets, lower(replace(key, "[^a-zA-Z0-9-]", "-")))
      ? lower(replace("${data.gitlab_project.project.name}-${key}", "[^a-zA-Z0-9-]", "-"))
      : lower(replace(key, "[^a-zA-Z0-9-]", "-"))
    ) => {
      value       = value.value
      environment = lookup(value, "environment_scope", "unknown")
      repo_name   = lower(replace(data.gitlab_project.project.name, "[^a-zA-Z0-9-]", "-"))
    }
  }
}

# Store all variables in the correct Azure Key Vault based on their environment
resource "azurerm_key_vault_secret" "all_secrets" {
  for_each     = local.all_variables

  # Valid name: Replace invalid characters with dashes
  name         = each.key
  value        = each.value.value
  content_type = each.value.repo_name  # Store the repo name in content_type for identification

  # Assign to the correct Key Vault based on the extracted environment
  key_vault_id = each.value.environment == "prod" ? data.azurerm_key_vault.prod_vault.id : data.azurerm_key_vault.stage_vault.id

  tags = {
    environment = each.value.environment  # Store environment as a tag
    repository  = each.value.repo_name    # Store repo name as a tag
  }

  lifecycle {
    ignore_changes = [value]  # Ignore changes to existing secret values
  }
}