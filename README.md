# OpenMPI on OCI Ampere (A2) Cluster

This project deploys a scalable OpenMPI cluster on Oracle Cloud Infrastructure (OCI) using **Ampere A1 (ARM-based)** instances. It supports dynamic cluster scaling, shared NFS storage, and is optimized for MPI workloads like GROMACS.

---

## 📐 Architecture Diagram

```
                    +-----------------------+
                    |       Bastion         |
                    |  (Head / Login Node)  |
                    |   Public IP Enabled   |
                    +----------+------------+
                               |
                  Shared NFS (via Export/Mount)
                               |
            +------------------+------------------+
            |                                     |
     +------+-------+                    +--------+------+
     |   Worker 1    |    ...            |   Worker N     |
     |  Ampere A1    |                   |  Ampere A1     |
     +--------------+                   +---------------+
```

* **Head Node (Bastion)**: Manages cluster, runs jobs, provides NFS share.
* **Workers**: Mount NFS, install OpenMPI, and register dynamically.
* **All nodes** use internal networking for MPI communication.

---

## 🚀 Deployment Steps

### Prerequisites

* OCI account with appropriate limits for Ampere A1 instances.
* `terraform` CLI installed locally.
* SSH key pair for cluster access.

### Step-by-step Guide

```bash
# 1. Clone the repository
$ git clone https://github.com/dezmaIT/OpenMPI-OCI-ARM.git
$ cd OpenMPI-OCI-ARM

# 2. Customize variables
$ cp terraform.tfvars.example terraform.tfvars
$ nano terraform.tfvars
# (Set values like compartment_ocid, availability_domain, etc.)

# 3. Configure an ssh key pair
$ ssh-keygen -b 2048 -t rsa -f <<sshkeyname>>

# 4. Add the keys to the terraform.tfvars file
ssh_private_key_path = "~/.ssh/id_rsa"
ssh_public_key  = "ssh-rsa AAAAB3NzaC1yc2E....."

# 5. Initialize and apply Terraform
$ terraform init
$ terraform apply -auto-approve

# 6. SSH into the head node
$ ssh -i <your_private_key> ubuntu@<public_ip_of_head>

# 7. Monitor worker provisioning via NFS shared logs
$ tail -f /mnt/mpi_shared/hostfile
```

---

## 🔧 Post-Deployment

After provisioning:

* `mpirun` will work from the head node using the dynamically built hostfile at `/mnt/mpi_shared/hostfile`.
* GROMACS or other MPI applications can be installed using the provided `gromacs-install.sh` script.
* All nodes use passwordless SSH and shared `/mnt/mpi_shared`.

---

## 📂 Directory Structure

```
OpenMPI-OCI-ARM/
├── terraform/               # Infrastructure code
├── scripts/                 # MPI + GROMACS bootstrap scripts
├── README.md                # This file
```

---

## 🧪 Example MPI Job

```bash
mpirun -np 16 --hostfile /mnt/mpi_shared/hostfile osu_latency
```

---

## 🛡️ License

MIT License. See `LICENSE` file.
