output "volumes" {
  description = "Map of created volumes"
  value = {
    for key, volume in databricks_volume.this : key => {
      id           = volume.id
      name         = volume.name
      catalog_name = volume.catalog_name
      schema_name  = volume.schema_name
      volume_type  = volume.volume_type
    }
  }
}
