data "azurerm_key_vault" "prod_vault" {
  name                = "prod-apollo-keyvault-03"
  resource_group_name = var.azure_resource_group
}

data "azurerm_key_vault" "stage_vault" {
  name                = "stage-apollo-keyvault-03"
  resource_group_name = var.azure_resource_group
}

data "gitlab_project" "project" {
  path_with_namespace = var.gitlab_project_path
}

data "github_repository" "repo" {
  name = var.github_repo_name
}

data "gitlab_project_variables" "secrets" {
  project = data.gitlab_project.project.id
}

locals {
  repo_suffix = lower(replace(var.github_repo_name, "/[^a-zA-Z0-9-]/", "-"))

  transformed_secrets = {
    for v in data.gitlab_project_variables.secrets.variables :
      format(
        "%s-%s-%s",
        lower(replace(v.key, "/[^a-zA-Z0-9-]/", "-")),
        length(v.environment_scope) > 0
          ? lower(replace(v.environment_scope, "/[^a-zA-Z0-9-]/", "-"))
          : "stage",
        local.repo_suffix
      )
    => {
      original_key = v.key
      value        = v.value
      environment  = (
        length(v.environment_scope) > 0
        ? lower(replace(v.environment_scope, "/[^a-zA-Z0-9-]/", "-"))
        : "stage"
      )
    }
  }
}

resource "azurerm_key_vault_secret" "all_secrets" {
  for_each = local.transformed_secrets

  name         = each.key
  value        = each.value.value
  content_type = local.repo_suffix

  key_vault_id = (
    each.value.environment == "production"
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