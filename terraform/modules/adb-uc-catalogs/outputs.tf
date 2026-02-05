output "catalogs" {
  description = "Map of created catalogs with their IDs"
  value = {
    for key, catalog in databricks_catalog.this : key => {
      id   = catalog.id
      name = catalog.name
    }
  }
}

output "schemas" {
  description = "Map of created schemas with their IDs"
  value = {
    for key, schema in databricks_schema.this : key => {
      id   = schema.id
      name = schema.name
    }
  }
}
