terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "~> 17.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "Backend-rg"
    storage_account_name = "backednstg755"
    container_name       = "backend-container"
    key                  = "secmigrate.tfstate"
    # key is provided dynamically via -backend-config in the workflow
  }
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}

provider "gitlab" {
  token    = var.gitlab_token
  base_url = "https://gitlab.com"
}

provider "azurerm" {
  features {}
  client_id       = var.AZURE_CLIENT_ID
  client_secret   = var.AZURE_CLIENT_SECRET
  subscription_id = var.AZURE_SUBSCRIPTION_ID
  tenant_id       = var.AZURE_TENANT_ID
}