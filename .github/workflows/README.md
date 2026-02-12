# GitHub Actions CI/CD for Azure Infrastructure

This directory contains GitHub Actions workflows for automating validation and deployment of the Azure Databricks, Azure ML, and AI Foundry platform.

---

## Workflows

### 1. Terraform Validation (`terraform-validate.yml`)
**Triggers:** Pull requests, pushes to main/develop branches

**Purpose:** Automated validation of infrastructure code changes before merging.

**Jobs:**
1. **Bicep Validation**
   - Lints Bicep files
   - Builds ARM templates
   - Checks for parameter placeholders

2. **Terraform Validation**
   - Format checking (`terraform fmt`)
   - Initialization and validation
   - Matrix strategy for metastore and environments

3. **Security Scanning**
   - Trivy: Infrastructure as Code scanning
   - Checkov: Compliance and security checks

4. **Documentation Check**
   - Validates required documentation exists
   - Detects TODO comments in production code

5. **Terraform Plan** (PR only)
   - Generates deployment preview
   - Posts plan as PR comment
   - Shows cost estimation

6. **Validation Summary**
   - Aggregates results from all jobs
   - Posts summary comment on PR

---

### 2. Terraform Deployment (`terraform-deploy.yml`)
**Triggers:** Manual workflow_dispatch

**Purpose:** Controlled deployment to dev, staging, or prod environments.

**Inputs:**
- `environment`: Target environment (dev/staging/prod)
- `component`: What to deploy (infrastructure/metastore/operational-config/all)

**Jobs:**
1. **Deploy Infrastructure** (Bicep)
   - Deploys Azure resources via `azd provision`
   - Creates VNet, Storage, Databricks, Azure ML, AI Foundry

2. **Deploy Metastore** (Terraform)
   - Creates Unity Catalog metastore
   - Configures catalogs and schemas

3. **Deploy Operational Config** (Terraform)
   - Deploys workspace configuration
   - Creates cluster policies
   - Sets up instance pools
   - Configures secret scopes

4. **Deployment Summary**
   - Aggregates deployment results
   - Posts summary with links to resources

---

## Setup Instructions

### Prerequisites
- Azure subscription with Owner or Contributor role
- Databricks account (Premium tier for Unity Catalog)
- GitHub repository with Actions enabled
- Azure CLI and Terraform installed locally (for testing)

### 1. Configure Azure OIDC Federation

**Why OIDC?** No secrets stored in GitHub - uses federated identity.

```bash
# 1. Create Azure AD App Registration
az ad app create --display-name "GitHub-Actions-OIDC-{project}"

# 2. Get app details
$appId = az ad app list --display-name "GitHub-Actions-OIDC-{project}" --query "[0].appId" -o tsv
$objectId = az ad app list --display-name "GitHub-Actions-OIDC-{project}" --query "[0].id" -o tsv

# 3. Create service principal
az ad sp create --id $appId

# 4. Assign Contributor role to subscription
az role assignment create --assignee $appId --role Contributor --scope /subscriptions/{subscription-id}

# 5. Configure federated credential for GitHub Actions
# Create file: github-federated-credential.json
{
  "name": "github-actions-federation",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:{github-org}/{github-repo}:ref:refs/heads/main",
  "description": "GitHub Actions OIDC for main branch",
  "audiences": [
    "api://AzureADTokenExchange"
  ]
}

# Apply federated credential
az ad app federated-credential create --id $objectId --parameters @github-federated-credential.json

# 6. Create additional credentials for develop and PR branches
# For develop branch
{
  "name": "github-actions-develop",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:{github-org}/{github-repo}:ref:refs/heads/develop",
  "audiences": ["api://AzureADTokenExchange"]
}

# For pull requests
{
  "name": "github-actions-pull-requests",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:{github-org}/{github-repo}:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}
```

### 2. Add GitHub Secrets

Navigate to: **GitHub Repo → Settings → Secrets and variables → Actions**

Add the following secrets:

| Secret Name | Value | How to Get |
|-------------|-------|------------|
| `AZURE_CLIENT_ID` | Service principal app ID | `az ad app list --display-name "GitHub-Actions-OIDC-{project}" --query "[0].appId"` |
| `AZURE_TENANT_ID` | Azure AD tenant ID | `az account show --query tenantId -o tsv` |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `az account show --query id -o tsv` |
| `DATABRICKS_ACCOUNT_ID` | Databricks account ID | Found in Databricks account console |

**Using GitHub CLI:**
```bash
gh secret set AZURE_CLIENT_ID --body "<app-id>"
gh secret set AZURE_TENANT_ID --body "<tenant-id>"
gh secret set AZURE_SUBSCRIPTION_ID --body "<subscription-id>"
gh secret set DATABRICKS_ACCOUNT_ID --body "<databricks-account-id>"
```

### 3. Configure Environment Protection Rules

**For Production Deployments:**

1. Go to **Settings → Environments → New environment**
2. Create environments: `dev`, `staging`, `prod`
3. For `prod` environment:
   - ✅ Enable **Required reviewers** (select team members)
   - ✅ Enable **Wait timer** (e.g., 5 minutes)
   - ✅ Enable **Deployment branches** (only main branch)

### 4. Test Workflows

#### Test Validation Workflow
```bash
# 1. Create a feature branch
git checkout -b test/github-actions

# 2. Make a small change (e.g., add comment to main.bicep)
echo "# Test comment" >> infra/main.bicep

# 3. Commit and push
git add infra/main.bicep
git commit -m "test: GitHub Actions validation"
git push origin test/github-actions

# 4. Create pull request
gh pr create --title "Test GitHub Actions" --body "Testing validation workflow"

# 5. Check workflow run
gh run list --workflow=terraform-validate.yml
```

#### Test Deployment Workflow
```bash
# 1. Navigate to GitHub Actions tab in repository
# 2. Select "Terraform Deploy" workflow
# 3. Click "Run workflow"
# 4. Select:
#    - Environment: dev
#    - Component: infrastructure
# 5. Click "Run workflow"
# 6. Monitor progress in Actions tab
```

---

## Workflow Features

### Security
- ✅ **No secrets stored** - Uses OIDC federation
- ✅ **Security scanning** - Trivy and Checkov
- ✅ **Least privilege** - Service principal with minimal permissions
- ✅ **Audit trail** - All deployments logged

### Quality
- ✅ **Code linting** - Bicep and Terraform format checks
- ✅ **Validation** - Syntax and semantic validation
- ✅ **Documentation checks** - Ensures docs are up to date
- ✅ **PR comments** - Terraform plan posted to PR

### Efficiency
- ✅ **Parallel execution** - Matrix strategy for multiple Terraform directories
- ✅ **Caching** - Terraform providers cached
- ✅ **Artifact sharing** - Terraform plan passed between jobs
- ✅ **Component deployment** - Deploy only what changed

---

## Customization

### Add New Environment
1. Create Terraform variable file: `terraform/environments/{env}.tfvars`
2. Update workflow environment selection
3. Configure environment protection in GitHub

### Add New Security Scanner
```yaml
- name: Run Snyk
  uses: snyk/actions/iac-test@master
  with:
    file: infra/
  env:
    SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
```

### Customize Notifications
Add Slack/Teams notification step:
```yaml
- name: Notify Slack
  if: always()
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
    payload: |
      {
        "text": "Deployment ${{ job.status }}: ${{ github.event.inputs.environment }}"
      }
```

---

## Troubleshooting

### Issue: OIDC authentication fails
**Error:** `AADSTS70021: No matching federated identity record found`

**Solution:**
1. Verify federated credential exists:
   ```bash
   az ad app federated-credential list --id $objectId
   ```
2. Check subject matches exactly: `repo:{org}/{repo}:ref:refs/heads/{branch}`
3. Ensure audiences includes `api://AzureADTokenExchange`

### Issue: Terraform plan fails
**Error:** `Error acquiring state lock`

**Solution:**
1. Check if another workflow is running
2. Manually unlock state:
   ```bash
   cd terraform/environments
   terraform force-unlock <lock-id>
   ```

### Issue: Security scan finds issues
**Solution:**
1. Review Trivy/Checkov output in workflow logs
2. Fix reported issues or add exceptions
3. For false positives, add inline comments:
   ```bicep
   // checkov:skip=CKV_AZURE_123: Reason for exception
   ```

### Issue: Deployment fails with permission error
**Error:** `AuthorizationFailed: does not have authorization to perform action`

**Solution:**
1. Grant additional permissions to service principal:
   ```bash
   az role assignment create --assignee $appId --role "Key Vault Administrator" --scope <key-vault-id>
   ```
2. Or assign custom role with specific permissions

---

## Best Practices

### PR Workflow
1. **Create feature branch** from `develop`
2. **Make changes** to infrastructure code
3. **Run local validation:**
   ```bash
   # Bicep
   az bicep build --file infra/main.bicep
   
   # Terraform
   cd terraform/environments
   terraform fmt -check
   terraform validate
   ```
4. **Create PR** to `develop`
5. **Review workflow results** - ensure all checks pass
6. **Review Terraform plan** in PR comments
7. **Get approvals** from team members
8. **Merge** to `develop`
9. **(For prod) Create PR** from `develop` to `main`
10. **Manual deployment** to prod via workflow_dispatch

### Deployment Workflow
1. **Always deploy to dev first**
2. **Validate deployment** before promoting
3. **Use component deployment** for targeted changes
4. **Monitor deployment logs** in real-time
5. **Run smoke tests** after deployment:
   ```bash
   ./infra/scripts/validate-deployment.ps1 -Environment dev
   ```

### Emergency Rollback
If deployment fails:
```bash
# 1. Identify last known good state
terraform state list

# 2. Re-run previous deployment
# Manually trigger workflow with previous commit SHA

# 3. Or restore from backup
./infra/scripts/restore-databricks-workspace.ps1 -BackupDate "2025-01-14"
```

---

## Monitoring

### View Workflow Runs
```bash
# List recent runs
gh run list --limit 10

# View specific run
gh run view <run-id>

# Watch run in real-time
gh run watch <run-id>

# Download logs
gh run download <run-id>
```

### Workflow Run Status API
```bash
# Get workflow run status
curl -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/repos/{org}/{repo}/actions/runs/{run-id}
```

---

## Cost Optimization

### Reduce Workflow Minutes
- ✅ Use caching for Terraform providers
- ✅ Skip validation on non-infrastructure changes
- ✅ Use matrix strategy efficiently
- ✅ Cancel in-progress runs when new commits are pushed

### Example: Skip workflow on docs-only changes
```yaml
on:
  pull_request:
    paths-ignore:
      - 'docs/**'
      - '**.md'
      - '.gitignore'
```

---

## References
- [GitHub Actions Documentation](https://docs.github.com/actions)
- [Azure OIDC Configuration](https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [Terraform GitHub Actions](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
- [Trivy IaC Scanning](https://aquasecurity.github.io/trivy/latest/docs/scanner/misconfiguration/)
- [Checkov Documentation](https://www.checkov.io/2.Basics/CLI%20Command%20Reference.html)

---

**Maintained By:** Platform Engineering Team  
**Last Updated:** January 2025
