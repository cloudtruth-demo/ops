variable "skip_final_snapshot" {
  description = "Flag to turn off the final snapshot on destruction of rds instances"
  default     = "false"
}

variable "service_sizing_default" {
  description = "Default service sizing parameters for when a service doesn't exist in service_sizing"
  type = object({
    min_capacity = number
    max_capacity = number
    cpu          = number
    memory       = number
  })
}

variable "service_sizing" {
  description = "Map of service name to sizing parameters"
  type = map(object({
    min_capacity = number
    max_capacity = number
    cpu          = number
    memory       = number
  }))
}

variable "db_sizing" {
  description = "Map of db name to sizing parameters for the databases used by services"
  type = map(object({
    count = number
    type  = string
  }))
}
