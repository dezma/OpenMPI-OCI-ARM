# ======================
# Data Sources
# ======================
data "oci_identity_availability_domain" "ad" {
  compartment_id = var.compartment_id
  ad_number      = 1
}

data "oci_core_images" "ubuntu_24_04_arm" {
  compartment_id           = var.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A2.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}
