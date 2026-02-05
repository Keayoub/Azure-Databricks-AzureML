variable "volumes" {
  description = "Map of volume definitions to create"
  type = map(object({
    catalog_name = string
    schema_name  = string
    name         = string
    comment      = optional(string, "")
    owner        = optional(string, null)
  }))
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
