# ======================
# Network Resources
# ======================
resource "oci_core_virtual_network" "mpi_cluster_vcn" {
  compartment_id = var.compartment_id
  cidr_block     = "10.0.0.0/16"
  display_name   = "mpi-cluster-vcn"
}

resource "oci_core_subnet" "public_subnet" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_virtual_network.mpi_cluster_vcn.id
  cidr_block     = "10.0.1.0/24"
  display_name   = "mpi-public-subnet"
  route_table_id = oci_core_route_table.public_rt.id
  security_list_ids = [oci_core_security_list.public_sl.id]
  prohibit_public_ip_on_vnic = false
}

resource "oci_core_subnet" "private_subnet" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_virtual_network.mpi_cluster_vcn.id
  cidr_block     = "10.0.2.0/24"
  display_name   = "mpi-private-subnet"
  route_table_id = oci_core_route_table.private_rt.id
  security_list_ids = [oci_core_security_list.private_sl.id]
  prohibit_public_ip_on_vnic = true
}

# ======================
# Gateways
# ======================
resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_virtual_network.mpi_cluster_vcn.id
  display_name   = "mpi-igw"
}

resource "oci_core_nat_gateway" "nat_gw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_virtual_network.mpi_cluster_vcn.id
  display_name   = "mpi-nat-gw"
}

resource "oci_core_service_gateway" "svc_gw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_virtual_network.mpi_cluster_vcn.id
  display_name   = "mpi-svc-gw"
  services {
    service_id = data.oci_core_services.all_services.services[0].id
  }
}

data "oci_core_services" "all_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

# ======================
# Route Tables
# ======================
resource "oci_core_route_table" "public_rt" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_virtual_network.mpi_cluster_vcn.id
  display_name   = "mpi-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}
resource "oci_core_route_table" "private_rt" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_virtual_network.mpi_cluster_vcn.id
  display_name   = "mpi-private-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat_gw.id
  }

  route_rules {
    destination       = data.oci_core_services.all_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.svc_gw.id
  }
}

# ======================
# Security Lists
# ======================

resource "oci_core_security_list" "public_sl" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_virtual_network.mpi_cluster_vcn.id
  display_name   = "mpi-public-sl"

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }
  
  ingress_security_rules {
    protocol = "all" # TCP
    source   = "10.0.2.0/24"
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_security_list" "private_sl" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_virtual_network.mpi_cluster_vcn.id
  display_name   = "mpi-private-sl"

  ingress_security_rules {
    protocol = "all"
    source   = "10.0.1.0/24" # Head node
  }
  ingress_security_rules {
    protocol = "all"
    source   = "10.0.2.0/24" # Workers
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}


resource "oci_core_network_security_group" "nfs_nsg" {
  compartment_id = var.compartment_id
  vcn_id        = oci_core_virtual_network.mpi_cluster_vcn.id
  display_name  = "mpi_nfs_nsg"
 
}

# NFS Core Ports
resource "oci_core_network_security_group_security_rule" "nfs_tcp" {
  network_security_group_id = oci_core_network_security_group.nfs_nsg.id
  direction                = "INGRESS"
  protocol                 = "6" # TCP
  source                   = oci_core_subnet.private_subnet.cidr_block
  source_type              = "CIDR_BLOCK"
  description              = "NFS TCP ports"
  
  tcp_options {
    destination_port_range {
      min = 2049
      max = 2050
    }
  }
}

resource "oci_core_network_security_group_security_rule" "nfs_udp" {
  network_security_group_id = oci_core_network_security_group.nfs_nsg.id
  direction                = "INGRESS"
  protocol                 = "17" # UDP
  source                   = oci_core_subnet.private_subnet.cidr_block
  source_type              = "CIDR_BLOCK"
  description              = "NFS UDP ports"
  
  udp_options {
    destination_port_range {
      min = 2049
      max = 2050
    }
  }
}

# Ancillary Services
resource "oci_core_network_security_group_security_rule" "nfs_services_tcp" {
  network_security_group_id = oci_core_network_security_group.nfs_nsg.id
  direction                = "INGRESS"
  protocol                 = "6" # TCP
  source                   = oci_core_subnet.private_subnet.cidr_block
  source_type              = "CIDR_BLOCK"
  description              = "NFS ancillary TCP services"
  
  tcp_options {
    destination_port_range {
      min = 111
      max = 111
    }
  }
}

resource "oci_core_network_security_group_security_rule" "nfs_services_udp" {
  network_security_group_id = oci_core_network_security_group.nfs_nsg.id
  direction                = "INGRESS"
  protocol                 = "17" # UDP
  source                   = oci_core_subnet.private_subnet.cidr_block
  source_type              = "CIDR_BLOCK"
  description              = "NFS ancillary UDP services"
  
  udp_options {
    destination_port_range {
      min = 111
      max = 111
    }
  }
}