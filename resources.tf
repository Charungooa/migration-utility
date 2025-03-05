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

# Define a mapping for secret environments if they are not in the name
variable "secret_environment_map" {
  type = map(string)
  default = {
    "api-key"   = "prod"
    "db-secret" = "staging"
    "test-var"  = "dev"
  }
}

# Process and classify variables (masked vs. unmasked)
locals {
  masked_variables = {
    for key, value in data.gitlab_project_variable.variables : key => {
      value       = value.value
      environment = (
        can(regex("dev", lower(key))) ? "dev" :
        can(regex("staging", lower(key))) ? "staging" :
        can(regex("prod", lower(key))) ? "prod" :
        lookup(var.secret_environment_map, key, "unknown") # Fallback to predefined mapping
      )
    }
    if value.masked  # Assume `masked` indicates sensitive secrets
  }

  unmasked_variables = {
    for key, value in data.gitlab_project_variable.variables : key => value.value
    if !value.masked  # Assume `!masked` indicates non-sensitive data
  }
}

# Store masked (sensitive) variables in Azure Key Vault with Environment & Type
resource "azurerm_key_vault_secret" "masked_secrets" {
  for_each     = local.masked_variables
  name         = replace(each.key, "_", "-")  # Sanitize key for Key Vault (no underscores)
  value        = each.value.value
  key_vault_id = data.azurerm_key_vault.existing_vault.id
  content_type = title(each.value.environment) # Dynamically set "Type" based on the environment

  tags = {
    environment = each.value.environment  # Store environment as tag (dev, staging, prod)
  }

  lifecycle {
    ignore_changes = [value]  # Ignore changes to existing secret values
  }
}

# Store unmasked (non-sensitive) variables in GitHub repository variables
resource "github_actions_variable" "unmasked_variables" {
  for_each      = local.unmasked_variables
  repository    = var.github_repo_name
  variable_name = each.key
  value         = each.value
}
