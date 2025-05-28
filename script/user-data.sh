#!/bin/bash
set -euo pipefail

# Download and execute the actual setup script
wget -O /tmp/hpc-setup.sh https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/1wxE2XOofANloz8Id7C81rbAt0k7P7hculDHYAtsTJ4JtIJtOZOFYZRQgmb3RdTT/n/fr9qm01oq44x/b/hpc/o/a2-hpc-setup.sh
chmod +x /tmp/hpc-setup.sh
sed -i 's/\r$//' /tmp/hpc-setup.sh


# Execute with the mount IP from Terraform
/tmp/hpc-setup.sh ${mount_ip} ${role}