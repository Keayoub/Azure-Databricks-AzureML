variable "environment_name" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment_name)
    error_message = "Environment must be dev, staging, or prod"
  }
}

# ========== Pool Creation Flags ==========
variable "create_general_purpose_pool" {
  description = "Create general purpose instance pool"
  type        = bool
  default     = true
}

variable "create_high_memory_pool" {
  description = "Create high memory instance pool"
  type        = bool
  default     = false
}

variable "create_compute_optimized_pool" {
  description = "Create compute optimized instance pool"
  type        = bool
  default     = false
}

variable "create_gpu_pool" {
  description = "Create GPU instance pool for ML workloads"
  type        = bool
  default     = false
}

# ========== General Settings ==========
variable "default_min_cores" {
  description = "Default minimum cores for node selection"
  type        = number
  default     = 4
}

variable "default_min_memory_gb" {
  description = "Default minimum memory in GB for node selection"
  type        = number
  default     = 16
}

variable "default_spark_version" {
  description = "Default Spark version to preload"
  type        = string
  default     = "13.3.x-scala2.12"
}

variable "idle_instance_autotermination_minutes" {
  description = "Minutes before idle instances are terminated"
  type        = number
  default     = 15
  
  validation {
    condition     = var.idle_instance_autotermination_minutes >= 5 && var.idle_instance_autotermination_minutes <= 1440
    error_message = "Idle instance autotermination must be between 5 minutes and 24 hours"
  }
}

variable "enable_elastic_disk" {
  description = "Enable elastic disk for instances"
  type        = bool
  default     = true
}

variable "enable_spot_instances" {
  description = "Enable spot instances for cost savings"
  type        = bool
  default     = false
}

variable "spot_bid_max_price" {
  description = "Maximum spot instance bid price (-1 for on-demand price)"
  type        = number
  default     = -1
}

variable "azure_availability" {
  description = "Azure availability type (SPOT_AZURE, ON_DEMAND_AZURE, SPOT_WITH_FALLBACK_AZURE)"
  type        = string
  default     = "ON_DEMAND_AZURE"
  
  validation {
    condition     = contains(["SPOT_AZURE", "ON_DEMAND_AZURE", "SPOT_WITH_FALLBACK_AZURE"], var.azure_availability)
    error_message = "Invalid Azure availability type"
  }
}

# ========== General Purpose Pool ==========
variable "general_purpose_node_type" {
  description = "Node type for general purpose pool (empty for auto-select)"
  type        = string
  default     = ""
}

variable "general_purpose_min_idle" {
  description = "Minimum idle instances in general purpose pool"
  type        = number
  default     = 0
}

variable "general_purpose_max_capacity" {
  description = "Maximum capacity of general purpose pool"
  type        = number
  default     = 10
}

variable "general_purpose_pool_permissions" {
  description = "Permissions for general purpose pool"
  type = list(object({
    group_name       = string
    permission_level = string
  }))
  default = []
}

# ========== High Memory Pool ==========
variable "high_memory_node_type" {
  description = "Node type for high memory pool"
  type        = string
  default     = "Standard_E8s_v3"
}

variable "high_memory_min_idle" {
  description = "Minimum idle instances in high memory pool"
  type        = number
  default     = 0
}

variable "high_memory_max_capacity" {
  description = "Maximum capacity of high memory pool"
  type        = number
  default     = 5
}

variable "high_memory_pool_permissions" {
  description = "Permissions for high memory pool"
  type = list(object({
    group_name       = string
    permission_level = string
  }))
  default = []
}

# ========== Compute Optimized Pool ==========
variable "compute_optimized_node_type" {
  description = "Node type for compute optimized pool"
  type        = string
  default     = "Standard_F8s_v2"
}

variable "compute_optimized_min_idle" {
  description = "Minimum idle instances in compute optimized pool"
  type        = number
  default     = 0
}

variable "compute_optimized_max_capacity" {
  description = "Maximum capacity of compute optimized pool"
  type        = number
  default     = 8
}

# ========== GPU Pool ==========
variable "gpu_node_type" {
  description = "Node type for GPU pool"
  type        = string
  default     = "Standard_NC6s_v3"
}

variable "gpu_min_idle" {
  description = "Minimum idle instances in GPU pool"
  type        = number
  default     = 0
}

variable "gpu_max_capacity" {
  description = "Maximum capacity of GPU pool"
  type        = number
  default     = 3
}

variable "gpu_spark_version" {
  description = "Spark version for GPU pool (ML runtime)"
  type        = string
  default     = ""
}

variable "gpu_pool_permissions" {
  description = "Permissions for GPU pool"
  type = list(object({
    group_name       = string
    permission_level = string
  }))
  default = []
}

# ========== Custom Pools ==========
variable "custom_pools" {
  description = "Custom instance pools to create"
  type = map(object({
    min_idle_instances                    = number
    max_capacity                          = number
    node_type_id                          = string
    idle_instance_autotermination_minutes = number
    preloaded_spark_versions              = list(string)
    azure_availability                    = string
    spot_bid_max_price                    = number
    enable_elastic_disk                   = bool
    custom_tags                           = map(string)
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to instance pools"
  type        = map(string)
  default     = {}
}
