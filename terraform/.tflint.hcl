# TFLint Configuration
# ====================
# Terraform linting for best practices and errors

plugin "azurerm" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

plugin "terraform" {
  enabled = true
  version = "0.9.1"
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"

  preset = "recommended"
}

config {
  # Enable module inspection
  module = true
  
  # Force provider initialization for data sources
  force = false
}

# Rule configurations
rule "terraform_naming_convention" {
  enabled = true
  
  format = "snake_case"
  
  # Variable naming
  variable {
    format = "snake_case"
  }
  
  # Output naming
  output {
    format = "snake_case"
  }
  
  # Local values naming
  locals {
    format = "snake_case"
  }
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_unused_required_providers" {
  enabled = true
}
