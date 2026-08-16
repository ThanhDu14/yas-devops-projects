variable "project_id"{
    description = "GCP Project ID"
    type = string
}

variable "region"{
    type = string
    default = "asia-southeast1"
}

variable "zone"{
    type = string
    default = "asia-southeast1-a"
}

variable "machine_type"{
    type = string
    default = "e2-standard-4"
}

