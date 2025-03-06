# Data sources for existing Azure Key Vaults
data "azurerm_key_vault" "prod_vault" {
  name                = "prod-apollo-keyvault"  # Hardcoded prod key vault
  resource_group_name = var.azure_resource_group
}

data "azurerm_key_vault" "stage_vault" {
  name                = "stage-apollo-keyvault"  # Hardcoded stage key vault
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

# Fetch individual variables along with their environment
data "gitlab_project_variable" "variables" {
  for_each = toset([
    for v in data.gitlab_project_variables.secrets.variables : v.key
  ])
  project     = data.gitlab_project.project.id
  key         = each.value
}

# Extracting variables and their environment from GitLab
locals {
  all_variables = {
    for key, value in data.gitlab_project_variable.variables : key => {
      value       = value.value
      environment = lookup(value, "environment_scope", "unknown")  # Extract environment from GitLab
    }
  }
}

# Store all variables in the correct Azure Key Vault based on their environment
resource "azurerm_key_vault_secret" "all_secrets" {
  for_each     = local.all_variables
  name         = replace(each.key, "_", "-")  # Sanitize key for Key Vault (no underscores)
  value        = each.value.value
  content_type = var.github_repo_name  # Use GitHub repo name as content_type

  # Assign to the correct Key Vault based on the extracted environment
  key_vault_id = each.value.environment == "prod" ? data.azurerm_key_vault.prod_vault.id : data.azurerm_key_vault.stage_vault.id

  tags = {
    environment = each.value.environment  # Store environment as a tag
  }

  lifecycle {
    ignore_changes = [value]  # Ignore changes to existing secret values
  }
}