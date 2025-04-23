# ======================
# Compute Resources
# ======================



resource "oci_core_instance" "mpi_head_node" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domain.ad.name
  shape               = "VM.Standard.A2.Flex"
  display_name        = "mpi-head-node"

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_ocpus * 8
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    assign_public_ip = true
    display_name     = "mpi-head-vnic"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu_24_04_arm.images[0].id
  }

  metadata = {
		ssh_authorized_keys = var.ssh_public_key
		user_data = base64encode(templatefile("${path.module}/script/user-data.sh", {
		  mount_ip    = oci_file_storage_mount_target.mpi_mount_target.ip_address
		  role = "head"
		
		}))
		
   }
}

resource "oci_core_instance_configuration" "mpi_worker_config" {
  compartment_id = var.compartment_id
  display_name   = "mpi-worker-config"

  instance_details {
    instance_type = "compute"

    launch_details {
      compartment_id = var.compartment_id
      shape          = "VM.Standard.A2.Flex"
      display_name   = "mpi-worker"

      shape_config {
        ocpus         = var.instance_ocpus
        memory_in_gbs = var.instance_ocpus * 8
      }

      create_vnic_details {
        subnet_id        = oci_core_subnet.private_subnet.id
        assign_public_ip = false
      }
      
      agent_config {
        are_all_plugins_disabled = false
        is_management_disabled  = false
        is_monitoring_disabled  = false
        
        plugins_config {
          desired_state = "ENABLED"
          name         = "Compute Instance Monitoring"
        }
        plugins_config {
          desired_state = "ENABLED"
          name         = "Custom Logs Monitoring"
        }
      }
      
      launch_options {
        network_type = "PARAVIRTUALIZED"
       
      }

      source_details {
        source_type = "image"
        image_id    = data.oci_core_images.ubuntu_24_04_arm.images[0].id 
      }
	  
	  metadata = {
		ssh_authorized_keys = var.ssh_public_key
		user_data = base64encode(templatefile("${path.module}/script/user-data.sh", {
		  mount_ip    = oci_file_storage_mount_target.mpi_mount_target.ip_address
		  role = "worker"
		
		}))
		
	  }
          
    }
  }
}

resource "oci_core_instance_pool" "mpi_workers" {
  compartment_id            = var.compartment_id
  instance_configuration_id = oci_core_instance_configuration.mpi_worker_config.id
  size                      = var.cluster_size
  display_name              = "mpi-worker-pool"

  placement_configurations {
    availability_domain = data.oci_identity_availability_domain.ad.name
    primary_subnet_id   = oci_core_subnet.private_subnet.id
  }
}
