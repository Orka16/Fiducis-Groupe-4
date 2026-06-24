# Suffixe aléatoire : le nom d'un compte de stockage doit être unique
# au niveau mondial (3-24 caractères, minuscules + chiffres uniquement).
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "backup" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "backup" {
  name                     = "stadbkpbdx${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.backup.name
  location                 = azurerm_resource_group.backup.location
  account_tier             = "Standard"
  account_replication_type = var.replication_type
  account_kind             = "StorageV2"
  access_tier              = "Cool" # sauvegardes peu relues => stockage moins cher

  # Durcissement
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true # nécessaire pour l'upload par clé (cf. script)

  blob_properties {
    versioning_enabled = true

    # Corbeille : un blob supprimé reste récupérable 30 jours
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "backup" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.backup.id
  container_access_type = "private"
}

# Cycle de vie : on descend en stockage froid puis archive, et on purge
# automatiquement les vieilles sauvegardes pour maîtriser les coûts.
resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.backup.id

  rule {
    name    = "expiration-sauvegardes-ad"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["${var.container_name}/"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 7
        tier_to_archive_after_days_since_modification_greater_than = 30
        delete_after_days_since_modification_greater_than          = 180
      }
      version {
        delete_after_days_since_creation = 90
      }
    }
  }
}
