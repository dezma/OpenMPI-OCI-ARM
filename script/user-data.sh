#!/bin/bash
set -euo pipefail

# Download and execute the actual setup script
wget -O /tmp/hpc-setup.sh  https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/BDZiMLgKvg7p-s3lT3jonYAbyCt_wxAlyt-BMZehWuu7C-0vaz24-EWoY3xDEE_N/n/fr9qm01oq44x/b/hpc/o/a2-hpc-setup.sh
chmod +x /tmp/hpc-setup.sh
sed -i 's/\r$//' /tmp/hpc-setup.sh


# Execute with the mount IP from Terraform
/tmp/hpc-setup.sh ${mount_ip} ${role}