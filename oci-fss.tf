# ======================
# Storage (OCI File Storage)
# ======================
resource "oci_file_storage_file_system" "mpi_nfs" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domain.ad.name
  display_name        = "mpi-nfs-fs"
  # Optional Specify higher performance tier
  #filesystem_snapshot_policy_id = oci_file_storage_filesystem_snapshot_policy.high_perf.id
}

resource "oci_file_storage_mount_target" "mpi_mount_target" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domain.ad.name
  subnet_id           = oci_core_subnet.private_subnet.id
  display_name        = "mpi-mount-target"
  hostname_label      = null # Disable DNS hostname
  nsg_ids             = [oci_core_network_security_group.nfs_nsg.id]
}

resource "oci_file_storage_export" "mpi_export" {
  export_set_id  = oci_file_storage_mount_target.mpi_mount_target.export_set_id
  file_system_id = oci_file_storage_file_system.mpi_nfs.id
  path           = "/mpi_shared"
}