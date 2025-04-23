#!/bin/bash
set -euo pipefail

# Download and execute the actual setup script
wget -O /tmp/hpc-setup.sh  https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/sOGfgE_Kl6JYLM1Ks84kEjWcZsHkU-n3L1wHUn4sxdmMMmeOBeRgL19wzvkUJo8j/n/fr9qm01oq44x/b/hpc/o/a2-hpc-setup.sh
chmod +x /tmp/hpc-setup.sh
sed -i 's/\r$//' /tmp/hpc-setup.sh


# Execute with the mount IP from Terraform
/tmp/hpc-setup.sh ${mount_ip} ${role}