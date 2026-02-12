# Databricks Workspace Configuration Module

## Overview

This module configures workspace-level Databricks settings including:

- **Workspace Configuration**: Unity Catalog, token management, serverless compute
- **IP Access Lists**: Allow/block lists for workspace access
- **Admin Groups**: Automated group creation and membership
- **Global Init Scripts**: Scripts that run on all clusters
- **Workspace Files**: Shared utilities and notebooks

## Features

### Security Configuration
- IP-based access control
- Token lifetime limits
- Secure init script management
- Workspace folder permissions

### Operational Settings
- Unity Catalog enablement
- Serverless compute configuration
- Databricks SQL serverless
- Deprecated features disabled

## Usage

```hcl
module "workspace_config" {
  source = "../modules/adb-workspace-config"

  # Basic settings
  enable_workspace_config         = true
  enable_unity_catalog           = true
  enable_serverless_compute      = true
  max_token_lifetime_days        = 90

  # IP Access Lists (optional)
  enable_ip_access_lists = true
  ip_access_lists = {
    corporate_network = {
      list_type    = "ALLOW"
      ip_addresses = ["198.51.100.0/24", "203.0.113.0/24"]
      enabled      = true
    }
  }

  # Admin Groups
  admin_groups = {
    "data-engineers" = {
      members = ["user1@example.com", "user2@example.com"]
    }
    "ml-team" = {
      members = ["mluser@example.com"]
    }
  }

  # Global Init Scripts
  global_init_scripts = {
    security_baseline = {
      enabled   = true
      source    = ""
      content   = <<-EOT
        #!/bin/bash
        # Security hardening
        echo "export SPARK_JAVA_OPTS=-Djava.security.manager" >> /databricks/spark/conf/spark-env.sh
      EOT
      content_base64 = ""
      position       = 1
    }
  }

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `enable_workspace_config` | Enable workspace configuration | `bool` | `true` | No |
| `enable_unity_catalog` | Enable Unity Catalog | `bool` | `true` | No |
| `enable_ip_access_lists` | Enable IP access lists | `bool` | `false` | No |
| `max_token_lifetime_days` | Maximum token lifetime (days) | `number` | `90` | No |
| `ip_access_lists` | IP access list configurations | `map(object)` | `{}` | No |
| `admin_groups` | Admin groups to create | `map(object)` | `{}` | No |
| `global_init_scripts` | Global init scripts | `map(object)` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| `workspace_configured` | Workspace configuration status |
| `ip_access_lists` | IP access lists created |
| `admin_groups` | Admin groups created |
| `global_init_scripts` | Global init scripts created |

## Best Practices

### IP Access Lists
- Use CIDR notation for ranges
- Start with ALLOW lists for corporate networks
- Test before enabling in production
- Monitor access denials

### Token Management
- Set reasonable lifetime limits (90 days recommended)
- Rotate tokens regularly
- Use service principals for automation

### Init Scripts
- Keep scripts idempotent
- Log all actions
- Test thoroughly before global deployment
- Use version control

### Admin Groups
- Use descriptive group names
- Align with organizational structure
- Regular access reviews

## Examples

### Corporate Network Lockdown
```hcl
ip_access_lists = {
  corporate_vpn = {
    list_type    = "ALLOW"
    ip_addresses = ["10.0.0.0/8"]
    enabled      = true
  }
}
```

### Development Environment Init Script
```hcl
global_init_scripts = {
  install_dev_tools = {
    enabled = true
    content = <<-EOT
      #!/bin/bash
      pip install --upgrade pip
      pip install pytest black flake8
    EOT
    position = 10
  }
}
```

## Security Considerations

- **IP Access Lists**: Carefully plan before enabling
- **Init Scripts**: Avoid storing secrets in scripts
- **Token Lifetime**: Balance security with usability
- **Group Membership**: Regular audits recommended

## Troubleshooting

### Common Issues

**IP Access List Lockout**
- Always include your current IP before enabling
- Have account admin access via Azure portal

**Init Script Failures**
- Check cluster event logs
- Verify script syntax
- Test on single cluster first

**Token Issues**
- Check workspace configuration for max lifetime
- Verify token hasn't expired

## References

- [Databricks Workspace Configuration](https://docs.databricks.com/en/admin/workspace-settings/index.html)
- [IP Access Lists](https://docs.databricks.com/en/security/network/ip-access-list.html)
- [Global Init Scripts](https://docs.databricks.com/en/init-scripts/global.html)
