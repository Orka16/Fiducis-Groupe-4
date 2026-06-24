variable "subscription_id" {
  description = "ID de l'abonnement Azure (az account show --query id -o tsv)"
  type        = string
}

variable "location" {
  description = "Région Azure"
  type        = string
  default     = "francecentral"
}

variable "resource_group_name" {
  description = "Nom du groupe de ressources"
  type        = string
  default     = "rg-ad-backup-bdx"
}

variable "container_name" {
  description = "Nom du conteneur blob qui reçoit les sauvegardes System State"
  type        = string
  default     = "ad-systemstate"
}

variable "replication_type" {
  description = "Redondance du compte de stockage : LRS (local) ou GRS (géo-redondant)"
  type        = string
  default     = "LRS"
}

variable "tags" {
  type = map(string)
  default = {
    projet      = "sauvegarde-ad"
    site        = "bordeaux"
    environnement = "prod"
  }
}
