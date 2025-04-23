# ======================
# Outputs
# ======================
output "mpi_head_node_public_ip" {
  value = oci_core_instance.mpi_head_node.public_ip
}

output "ssh_command" {
  value = "ssh -o ProxyCommand='ssh -W %h:%p -i <private-key> ubuntu@${oci_core_instance.mpi_head_node.public_ip}' -i <private-key> ubuntu@<worker_private_ip>"
}




output "cluster_access" {
  value = <<-EOT
    # Access cluster via:
    ssh -i ~/.ssh/your_key ubuntu@${oci_core_instance.mpi_head_node.public_ip}

    # Verify hostfile:
    cat /mnt/mpi_shared/hostfile

    # Run MPI job:
    mpirun --hostfile /mnt/mpi_shared/hostfile -np $(( ${var.cluster_size} * ${var.instance_ocpus} )) mca pml ob1 \\
      ./your_app
  EOT
}