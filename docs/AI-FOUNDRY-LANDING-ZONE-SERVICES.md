# AI Foundry Landing Zone Optional Services

This guide covers the optional AI Foundry Landing Zone components integrated into the Databricks + Azure ML deployment.

## Overview

The deployment supports 4 optional services designed following Microsoft's [Azure AI Landing Zones](https://github.com/Azure/AI-Landing-Zones) architecture pattern:

| Service | Purpose | RG | SKU | Cost | Notes |
|---------|---------|----|----|------|-------|
| **App Configuration** | Feature flags, settings management | Shared Services | Standard | ~$2/day | Centralized config, no charge for data access |
| **API Management** | API gateway, versioning, analytics | Shared Services | Developer | ~$1/hour | Internal VNet, developer tier for dev/test |
| **AI Search** | Semantic + vector search, RAG | AI Platform | Standard | ~$2.50/hour | Includes semantic search (free tier), vector search ready |
| **Cosmos DB** | NoSQL for chat history, agents, docs | AI Platform | Serverless | Pay-per-request | Auto-scaling, low cost for variable workloads |

---

## Enabling Services

Edit **`infra/main.bicepparam`** or **`infra/main.local.bicepparam`**:

```bicepparam
// Set to true to deploy
param deployAppConfiguration = false   // → true to enable
param deployAPIM = false              // → true to enable  
param deployAISearch = false           // → true to enable
param deployCosmosDB = false           // → true to enable

// Configure SKUs (optional)
param aiSearchSku = 'standard'
param apimSku = 'Developer'  // Use 'Developer' for dev, 'Standard' for prod
param cosmosDbConsistencyLevel = 'Session'
param apimPublisherEmail = 'admin@yourdomain.com'
param apimPublisherName = 'Your Organization'
```

Then deploy:
```bash
azd provision
```

---

## Resource Group Organization

| Resource Group | Purpose | Resources |
|---|---|---|
| **rg-{env}-{project}-shared** | Shared services | Networking, Storage, ACR, Key Vault, **App Config, APIM** |
| **rg-{env}-{project}-databricks** | Databricks workspace | Databricks, Unity Catalog, managed RG |
| **rg-{env}-{project}-ai-platform** | ML & AI services | Azure ML, AI Foundry, **AI Search, Cosmos DB** |
| **rg-{env}-{project}-compute** | Container orchestration | AKS, Azure Container Apps |

---

## Azure App Configuration

**Purpose**: Centralized management of feature flags and application settings.

**When to use**:
- Feature flags for A/B testing or gradual rollout
- Environment-specific settings (API endpoints, timeout values)
- Centralized key management without storing in code
- Multi-tenant configuration

### Architecture
- **SKU**: Standard (no differences from Premium for this scenario)
- **Access**: Private endpoint in shared services VNet
- **Auth**: Managed Identity from client applications
- **DNS**: `privatelink.azconfig.io` private zone

### Quick Setup

```bash
# 1. Get App Configuration endpoint
APP_CONFIG_ENDPOINT=$(az deployment group show \
  --resource-group rg-dev-dbxaml-shared \
  --name appconfiguration-deployment \
  --query properties.outputs.appConfigEndpoint.value -o tsv)

# 2. Add configuration key-value
az appconfig kv set \
  --endpoint $APP_CONFIG_ENDPOINT \
  --key "FeatureFlags/RagEnabled" \
  --value "true" \
  --label "production"

# 3. Query from your application
curl "$APP_CONFIG_ENDPOINT/kv/FeatureFlags%2FRagEnabled?label=production" \
  -H "Authorization: Bearer $(az account get-access-token --query accessToken -o tsv)"
```

### Integration Example (Python)

```python
from azure.identity import DefaultAzureCredential
from azure.appconfiguration import AzureAppConfigurationClient

# Using managed identity
credential = DefaultAzureCredential()
client = AzureAppConfigurationClient(
    config_store_url=app_config_endpoint,
    credential=credential
)

# Get feature flag
rag_enabled = client.get_configuration_setting(
    key="FeatureFlags/RagEnabled"
).value == "true"
```

---

## API Management (APIM)

**Purpose**: Unified API gateway for AI services with versioning, throttling, and analytics.

**When to use**:
- Central gateway for multiple microservices
- API versioning and backward compatibility
- Rate limiting and quota management
- API analytics and monitoring
- Security (IP whitelisting, JWT validation)

### Architecture
- **Mode**: Internal VNet (no public IP)
- **SKU**: Developer (single instance, dev/test only)
- **Auth**: Managed Identity
- **DNS**: 4 private zones (portal, developer, management, gateway)
- **Monitoring**: Application Insights integration
- **Location**: 10.0.9.0/24 subnet

### Quick Setup

```bash
# 1. Get APIM gateway URL
APIM_URL=$(az deployment group show \
  --resource-group rg-dev-dbxaml-shared \
  --name apim-deployment \
  --query properties.outputs.apimGatewayUrl.value -o tsv)

# 2. Create API backend pointing to AI Foundry
az apim api create \
  --resource-group rg-dev-dbxaml-shared \
  --api-management-instance myapim \
  --api-id ai-foundry-api \
  --display-name "AI Foundry API" \
  --service-url "https://ai-foundry-hub.openai.azure.com/" \
  --path "/ai-foundry"

# 3. Access through APIM
# Gateway: https://{apim-instance}.azure-api.net/ai-foundry
```

### Add API to APIM (Azure Portal)

1. Open API Management instance
2. APIs → + Add API
3. Select "HTTP"
4. **Display name**: "Chat API"
5. **Web service URL**: `https://ai-foundry-hub.openai.azure.com/chat`
6. **API URL suffix**: `/chat`
7. **Products**: Default (or create new)
8. Create

### Rate Limiting Example

```xml
<!-- Create policy in APIM -->
<policies>
  <inbound>
    <!-- Rate limit: 100 calls per 60 seconds -->
    <rate-limit 
      calls="100" 
      renewal-period="60" 
      retry-after-header-name="Retry-After" />
    <!-- Add API key requirement -->
    <validate-jwt header-name="Authorization" failed-validation-httpcode="401">
      <openid-config url="https://login.microsoftonline.com/common/.well-known/openid-configuration" />
    </validate-jwt>
  </inbound>
  <outbound>
    <base />
  </outbound>
</policies>
```

---

## AI Search

**Purpose**: Semantic and vector search for RAG (Retrieval-Augmented Generation) scenarios.

**When to use**:
- Document search with semantic ranking
- Vector similarity search for embeddings
- Hybrid search combining keyword + semantic
- Powering RAG applications with AI assistants
- Indexing product catalogs or knowledge bases

### Architecture
- **SKU**: Standard S1 (1 GB, good for development)
- **Access**: Private endpoint in AI Platform VNet
- **Capabilities**: Semantic search (free tier), vector search, full-text search
- **Auth**: Managed Identity + API key
- **DNS**: `privatelink.search.windows.net` private zone

### Quick Setup

```bash
# 1. Get AI Search endpoint
SEARCH_ENDPOINT=$(az deployment group show \
  --resource-group rg-dev-dbxaml-ai-platform \
  --name aisearch-deployment \
  --query properties.outputs.aiSearchEndpoint.value -o tsv)

# 2. Create an index with vector search
curl -X POST "$SEARCH_ENDPOINT/indexes?api-version=2024-07-01-preview" \
  -H "api-key: $(az search admin-key show -g rg-dev-dbxaml-ai-platform -s mysearch --query primaryKey -o tsv)" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "documents",
    "fields": [
      {"name": "id", "type": "Edm.String", "key": true},
      {"name": "title", "type": "Edm.String", "searchable": true},
      {"name": "content", "type": "Edm.String", "searchable": true},
      {"name": "embedding", "type": "Collection(Edm.Single)", "searchable": true, "retrievable": true, "dimensions": 1536, "vectorSearchConfiguration": "default"}
    ],
    "vectorSearch": {
      "algorithms": [
        {"name": "myalgorithm", "kind": "hnsw"}
      ],
      "profiles": [
        {"name": "default", "algorithm": "myalgorithm"}
      ]
    },
    "semantic": {
      "configurations": [
        {
          "name": "default",
          "prioritizedFields": {
            "titleField": {"fieldName": "title"},
            "contentFields": [{"fieldName": "content"}]
          }
        }
      ]
    }
  }'
```

### Semantic Search Query (Python)

```python
from azure.search.documents import SearchClient
from azure.identity import DefaultAzureCredential

credential = DefaultAzureCredential()
client = SearchClient(endpoint=search_endpoint, index_name="documents", credential=credential)

# Semantic search
results = client.search(
    search_text="machine learning best practices",
    search_fields=["title", "content"],
    semantic_configuration_name="default",
    query_type="semantic"
)

for result in results:
    print(f"Title: {result['title']}")
    print(f"Score: {result['@search.score']}")
    print(f"Semantic score: {result['@search.semantic_score']}")
```

### Vector Search Query (Python)

```python
# First, embed your query text using Azure OpenAI
embeddings = client.embeddings.create(
    input="best practices for RAG applications",
    model="text-embedding-3-small"
)
query_vector = embeddings.data[0].embedding

# Search by vector similarity
results = client.search(
    search_text=None,
    vector_queries=[{
        "kind": "vector",
        "vector": query_vector,
        "fields": "embedding",
        "k": 5
    }]
)
```

---

## Cosmos DB

**Purpose**: NoSQL database for AI application state (chat sessions, agents, documents).

**When to use**:
- Chat history and conversation logging
- User context and session state
- AI agent memory and preferences
- Document metadata for RAG
- Multi-tenant data isolation by user/tenant ID
- Globally distributed applications

### Architecture
- **API**: NoSQL (SQL API)
- **Mode**: Serverless (auto-scaling)
- **Consistency**: Session (default, good for most apps)
- **Auth**: Managed Identity + connection string
- **DNS**: `privatelink.documents.azure.com` private zone
- **Databases**: 3 included (chat-sessions, agents, documents)

### Included Databases & Containers

| Database | Container | Partition Key | Purpose | TTL |
|---|---|---|---|---|
| **chat-sessions** | sessions | `/userId` | Chat history per user | 30 days |
| **agents** | agents | `/agentId` | Agent configurations | None |
| **documents** | documents | `/documentId` | Document metadata for RAG | None |

### Quick Setup

```bash
# 1. Get Cosmos DB endpoint
COSMOS_ENDPOINT=$(az deployment group show \
  --resource-group rg-dev-dbxaml-ai-platform \
  --name cosmosdb-deployment \
  --query properties.outputs.cosmosDbEndpoint.value -o tsv)

# 2. Get connection string
COSMOS_CONNECTION=$(az cosmosdb keys list \
  --resource-group rg-dev-dbxaml-ai-platform \
  --name mycosmosaccount \
  --type connection-strings \
  --query connectionStrings[0].connectionString -o tsv)
```

### Chat Session Storage (Python)

```python
from azure.cosmos import CosmosClient
from datetime import datetime, timedelta

client = CosmosClient.from_connection_string(cosmos_connection)
db_client = client.get_database_client("chat-sessions")
container = db_client.get_container_client("sessions")

# Save chat session
session = {
    "id": f"{user_id}_{session_id}",
    "userId": user_id,
    "messages": [
        {
            "role": "user",
            "content": "What is RAG?",
            "timestamp": datetime.utcnow().isoformat()
        },
        {
            "role": "assistant",
            "content": "RAG stands for Retrieval-Augmented Generation...",
            "timestamp": datetime.utcnow().isoformat()
        }
    ],
    "createdAt": datetime.utcnow().isoformat()
}

container.create_item(body=session)

# Query sessions for a user (scoped by partition key)
query = "SELECT * FROM sessions WHERE sessions.userId = @userId ORDER BY sessions.createdAt DESC"
items = container.query_items(
    query=query,
    parameters=[{"name": "@userId", "value": user_id}]
)
```

### Agent Configuration (Python)

```python
from azure.cosmos import CosmosClient

agents_db = client.get_database_client("agents")
agents_container = agents_db.get_container_client("agents")

# Save agent config
agent = {
    "id": agent_id,
    "agentId": agent_id,
    "name": "RAG Assistant",
    "systemPrompt": "You are a helpful AI assistant specialized in...",
    "tools": ["search", "summarize", "execute-code"],
    "model": "gpt-4",
    "temperature": 0.7,
    "maxTokens": 2000,
    "createdAt": datetime.utcnow().isoformat()
}

agents_container.create_item(body=agent)

# Get agent by ID (requires partition key)
agent = agents_container.read_item(
    item=agent_id,
    partition_key=agent_id
)
```

### Document Metadata (Python)

```python
documents_db = client.get_database_client("documents")
docs_container = documents_db.get_container_client("documents")

# Index document metadata
doc_metadata = {
    "id": f"doc_{uuid.uuid4()}",
    "documentId": f"doc_{uuid.uuid4()}",
    "title": "Enterprise AI Best Practices",
    "source": "internal-wiki",
    "chunks": 42,
    "embedding_model": "text-embedding-3-small",
    "size_bytes": 125000,
    "indexed_at": datetime.utcnow().isoformat(),
    "tags": ["ai", "best-practices", "enterprise"]
}

docs_container.create_item(body=doc_metadata)

# Query documents by tags
query = "SELECT * FROM documents WHERE ARRAY_CONTAINS(documents.tags, @tag)"
docs = docs_container.query_items(
    query=query,
    parameters=[{"name": "@tag", "value": "ai"}]
)
```

### Consistency Levels

| Level | Guarantees | Use Case |
|-------|-----------|----------|
| **Strong** | ACID across replicas | Financial transactions |
| **Bounded Staleness** | Ordered reads, configurable lag | Most applications |
| **Session** | Read your writes, per session | **Recommended for chat/agents** |
| **Eventual** | Best performance | Analytics, telemetry |
| **Consistent Prefix** | Ordered writes | Logging, feeds |

---

## Integration Patterns

### Pattern 1: RAG with Search + Cosmos DB

```
User Query
    ↓
[APIM API Gateway]
    ↓
[AI Foundry Chat API]
    ├→ [AI Search] - Find relevant documents
    ├→ [Cosmos DB] - Fetch user context/chat history
    └→ [Azure OpenAI] - Generate response
    ↓
Response + Citations
```

### Pattern 2: Feature-Gated AI Services

```
User Request
    ↓
[APIM] - Rate limiting, versioning
    ↓
[App Config] - Check feature flag "RagEnabled"
    ├→ If true: Route to RAG pipeline
    └→ If false: Route to standard API
    ↓
[Cosmos DB] - Log interaction
```

### Pattern 3: Agent with Memory

```
Agent Request
    ↓
[Cosmos DB] - Fetch agent config + conversation history
    ↓
[AI Search] - Find tool docs/knowledge
    ↓
[Azure OpenAI] - Generate next step
    ↓
[Cosmos DB] - Save interaction for audit/memory
```

---

## Monitoring & Diagnostics

### View Resource Logs

```bash
# App Configuration
az monitor diagnostics-settings create \
  --resource rg-dev-dbxaml-shared/providers/Microsoft.AppConfiguration/configurationStores/myappconfig \
  --logs '[{"category":"HttpRequest","enabled":true}]' \
  --workspace rg-dev-dbxaml-shared/providers/Microsoft.OperationalInsights/workspaces/myworkspace

# APIM
az apim diagnostic create \
  --resource-group rg-dev-dbxaml-shared \
  --apim-name myapim \
  --diagnostic-id applicationinsights \
  --logger-id /subscriptions/{subId}/resourceGroups/rg-dev-dbxaml-shared/providers/microsoft.insights/components/myappinsights

# AI Search
az search diagnostic-setting create \
  --resource-group rg-dev-dbxaml-ai-platform \
  --resource-name mysearch \
  --resource-type searchServices \
  --logs '[{"category":"OperationLogs","enabled":true}]' \
  --workspace myworkspace

# Cosmos DB
az cosmosdb diagnostic-settings create \
  --resource-group rg-dev-dbxaml-ai-platform \
  --name mycosmosdb \
  --logs '[{"category":"DataPlaneRequests","enabled":true}]' \
  --workspace myworkspace
```

### Query Logs in Log Analytics

```kusto
// APIM request failures
ApiManagementGatewayLogs
| where isnotempty(BackendResponseCode) 
  and BackendResponseCode >= 400
| summarize count() by BackendResponseCode, OperationName
| order by count_ desc

// Cosmos DB slow queries
CosmosDiagnosticLogs
| where DurationMs > 1000
| project TimeGenerated, DatabaseName, CollectionName, OperationName, DurationMs
| order by DurationMs desc

// AI Search indexing errors
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.SEARCH"
| where Level == "Error"
```

---

## Cost Optimization

| Service | Cost Driver | Optimization |
|---------|-------------|--------------|
| **App Configuration** | Data access | Cache locally in app |
| **APIM** | Requests + instances | Use Developer SKU for dev, Standard for prod |
| **AI Search** | Replicas + partitions | Start with S1 (1 partition), scale up only if needed |
| **Cosmos DB** | RU/s consumption | Use serverless for variable workloads, monitor request patterns |

### Estimate Monthly Costs

```
Dev/Test Environment:
- App Configuration Standard: $1.50/day = $45/month
- APIM Developer: $1/hour = $730/month (always on)
- AI Search S1: $2.50/hour = $1,800/month (always on)
- Cosmos DB Serverless: ~$1.25/million RUs = $10-50/month

Total: ~$2,600/month for all 4 services

Cost-saving tips:
1. Stop APIM and AI Search resources when not in use (dev)
2. Use Cosmos DB serverless (not provisioned)
3. Use App Config Standard (no difference from Premium)
4. Disable vector search indexing if not used
```

---

## Troubleshooting

### App Configuration: Can't connect

```bash
# Check private endpoint connectivity
az network private-endpoint-connection list \
  --id /subscriptions/{subId}/resourceGroups/rg-dev-dbxaml-shared/providers/Microsoft.AppConfiguration/configurationStores/myappconfig

# Verify DNS resolution
nslookup privatelink.azconfig.io
```

### APIM: Gateway not accessible

```bash
# Check APIM internal IP
az apim show \
  --resource-group rg-dev-dbxaml-shared \
  --name myapim \
  --query privateIPAddresses

# Verify Network Security Group rules
az network nsg rule list \
  --resource-group rg-dev-dbxaml-shared \
  --nsg-name apimNsg
```

### AI Search: Can't index documents

```bash
# Check indexer status
az search indexer show \
  --resource-group rg-dev-dbxaml-ai-platform \
  --search-service-name mysearch \
  --indexer-name mydocuments-indexer

# View indexer execution history
az search indexer get-status \
  --resource-group rg-dev-dbxaml-ai-platform \
  --search-service-name mysearch \
  --indexer-name mydocuments-indexer
```

### Cosmos DB: High RU consumption

```bash
# Check collection usage
az cosmosdb sql container metrics list \
  --resource-group rg-dev-dbxaml-ai-platform \
  --account-name mycosmosdb \
  --database-name chat-sessions \
  --name sessions \
  --filter "DatabaseName eq 'chat-sessions' and CollectionName eq 'sessions'"
```

---

## Next Steps

1. **Enable individual services** by setting deployment flags to `true`
2. **Test integration** between services using provided examples
3. **Set up monitoring** dashboards in Application Insights
4. **Configure backup** for Cosmos DB if using for production
5. **Review security** - all services use managed identities and private endpoints
6. **Document** your custom API operations in APIM

For detailed API documentation, see:
- [Azure App Configuration REST API](https://learn.microsoft.com/rest/api/appconfiguration/)
- [API Management REST API](https://learn.microsoft.com/rest/api/apimanagement/)
- [Azure Search REST API](https://learn.microsoft.com/rest/api/searchservice/)
- [Cosmos DB REST API](https://learn.microsoft.com/rest/api/cosmos-db-resource-provider/)
