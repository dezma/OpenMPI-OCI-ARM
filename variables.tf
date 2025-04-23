# ======================
# Variables
# ======================
variable "compartment_id" {
  description = "OCI Compartment ID"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key"
  type        = string
}

variable "region" {
  default = "us-phoenix-1"
}

variable "cluster_size" {
  default = 4
}

variable "instance_ocpus" {
  default = 8  # Ampere A2.Flex cores per node
}
