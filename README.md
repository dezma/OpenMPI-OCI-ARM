# Oracle Cloud Ampere A2 MPI Cluster Terraform Configuration

## Overview
This Terraform configuration creates a high-performance computing (HPC) cluster on Oracle Cloud Infrastructure (OCI) using Ampere A2 instances, optimized for MPI (Message Passing Interface) workloads.

## Features
- Creates a complete HPC environment with networking infrastructure  
- Deploys Ampere A2 compute nodes (ARM64 architecture)  
- Includes a bastion host for secure access  
- Sets up shared NFS storage for cluster-wide file access  
- Configures OpenMPI on all compute nodes  
- Implements placement groups for low-latency inter-node communication  
- Provides secure networking with public/private subnets  

## Prerequisites
1. **Oracle Cloud Account**: You need an OCI account with appropriate permissions  
2. **Terraform**: Version 1.0.0 or higher installed  
3. **OCI CLI**: Configured with your credentials  
4. **SSH Keys**: A key pair for accessing the instances  

## Configuration
### Required Variables
Set these variables in a `terraform.tfvars` file or as environment variables:

```hcl
tenancy_ocid = "ocid1.tenancy.oc1..xxxxx"
compartment_ocid = "ocid1.compartment.oc1..xxxxx"
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2E..."
ssh_private_key_path = "~/.ssh/id_rsa"
```


## Optional Variables
You can override these defaults as needed. Add these to your terraform.tfvars:

```hcl
region = "us-ashburn-1"         # Default region
cluster_name = "ampere-a2-cluster" # Name prefix for all resources
node_count = 4                  # Number of compute nodes
ad = 1                          # Availability domain number
```


## Architecture
The configuration creates:

### Networking:

- VCN with public and private subnets

- Internet Gateway, NAT Gateway, and Service Gateway

- Route tables and security lists

### Compute:

- 1 Bastion host (VM.Standard.A1.Flex) in public subnet

- N Compute nodes (VM.Standard.A2.Flex) in private subnet

- Cluster placement group for optimal node placement

### Storage:

- Shared NFS filesystem mounted on all nodes

- Mount target in dedicated subnet

### Software:

- OpenMPI 4.1.5 installed on all nodes

- NFS client configured on compute nodes