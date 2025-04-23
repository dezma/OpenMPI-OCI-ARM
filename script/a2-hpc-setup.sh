#!/bin/bash
set -euo pipefail
MOUNT_IP=$1
ROLE=$2   # First argument indicates role: head or 
LOG_FILE="/var/log/mpi-setup-$(date +%s).log"
exec > "$LOG_FILE" 2>&1

# Validate input
if [[ -z "$MOUNT_IP" || -z "$ROLE" ]]; then
    echo "ERROR: Missing NFS mount IP or role parameter"
    exit 1
fi

# Initialize
CORES=$(nproc)


echo "=== OCI A2 MPI SETUP ($ROLE NODE) ==="

# System Tuning
echo "=== SYSTEM OPTIMIZATION ==="
{
    # Network Tuning
    cat > /etc/sysctl.d/99-mpi.conf <<'EOT'
# TCP Tuning
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_sack=1
net.core.netdev_max_backlog=30000
net.core.somaxconn=32768
net.ipv4.tcp_low_latency=1

# Virtual NIC Optimization
net.core.netdev_budget=6000
net.ipv4.tcp_retries2=8
EOT

    sysctl -p /etc/sysctl.d/99-mpi.conf

    PRIMARY_IF=$(ip -o -4 route show to default | awk '{print $5}')
    ethtool -K $PRIMARY_IF tx on rx on tso on gso on gro on || true
    ethtool -G $PRIMARY_IF rx 4096 tx 4096 || true
    ip link set $PRIMARY_IF mtu 9000 || true

    DEFAULT_ROUTE=$(ip -o -4 route show default)
    SUBNET=$(echo "$DEFAULT_ROUTE" | awk '{print $3}' | awk -F'.' '{print $1"."$2"."$3".0/24"}')

    if ! [[ $SUBNET =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        echo "ERROR: Invalid subnet detected: $SUBNET"
        echo "Using fallback: 10.0.0.0/16"
        SUBNET="10.0.0.0/16"
    fi

    sudo iptables -F
    sudo iptables -A INPUT -s "$SUBNET" -j ACCEPT
    sudo iptables -A OUTPUT -d "$SUBNET" -j ACCEPT
}

echo "=== INSTALLING PACKAGES ==="
{
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        gcc-13 g++-13 libstdc++-13-dev \
        libevent-dev libhwloc-dev hwloc-nox \
        libnuma-dev ethtool net-tools \
        nfs-common wget cmake pkg-config \
        git automake libtool unzip
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 100
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 100
}

echo "=== CONFIGURING NFS ==="
{
    mkdir -p /mnt/mpi_shared
    chmod 1777 /mnt/mpi_shared

    MOUNT_SUCCESS=0
    for version in 4.2 4.1 3; do
        echo "Trying NFSv${version}..."
        if mount -t nfs -o "vers=${version},rsize=65536,wsize=65536,hard,timeo=600,retrans=2" "${MOUNT_IP}:/mpi_shared" /mnt/mpi_shared; then
            echo "${MOUNT_IP}:/mpi_shared /mnt/mpi_shared nfs vers=${version},rsize=65536,wsize=65536,hard,timeo=600,retrans=2 0 0" >> /etc/fstab
            MOUNT_SUCCESS=1
            break
        fi
    done

    if [ "$MOUNT_SUCCESS" -eq 0 ]; then
        echo "ERROR: Failed to mount NFS share"
        rpcinfo -p "${MOUNT_IP}" || true
        showmount -e "${MOUNT_IP}" || true
        exit 1
    fi
    mount | grep mpi_shared

    if [[ "$ROLE" == "head" ]]; then
        echo "$(hostname -I | awk '{print $1}') slots=$CORES" >> /mnt/mpi_shared/hostfile
    fi
}

if [[ "$ROLE" == "head" ]]; then
    echo "=== HEAD NODE SETUP ==="
    echo "Head node: ${HOSTNAME} is ready."
else
    echo "=== WORKER NODE SETUP ==="
    echo "$(hostname -I | awk '{print $1}') slots=$CORES" >> /mnt/mpi_shared/hostfile
fi

echo "=== BUILDING OPENMPI ==="
{
    cd /opt || mkdir -p /opt
    wget https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-4.1.5.tar.gz
    tar xzf openmpi-4.1.5.tar.gz
    cd openmpi-4.1.5

    ./configure --prefix=/usr/local \
        --with-pmix=internal \
        --with-hwloc=internal \
        --enable-mpi1-compatibility \
        --disable-dlopen \
        --without-verbs \
        CFLAGS="-O3 -mcpu=ampere1 -march=armv8.6-a -funroll-loops -ffast-math" \
        CXXFLAGS="-O3 -mcpu=ampere1 -march=armv8.6-a -funroll-loops -ffast-math"

    make -j$((CORES/2))
    make install
    ldconfig
}

echo "=== CONFIGURING PASSWORDLESS SSH ==="
{
    [ -f /home/ubuntu/.ssh/authorized_keys ] && \
        sudo cp /home/ubuntu/.ssh/authorized_keys /home/ubuntu/.ssh/authorized_keys.bak

    sudo -u ubuntu mkdir -p /home/ubuntu/.ssh
    sudo chmod 700 /home/ubuntu/.ssh

    if [ ! -f /home/ubuntu/.ssh/id_rsa ]; then
        sudo -u ubuntu ssh-keygen -t rsa -N "" -f /home/ubuntu/.ssh/id_rsa
    fi

    sudo mkdir -p /mnt/mpi_shared/ssh_keys
    sudo cp /home/ubuntu/.ssh/id_rsa.pub /mnt/mpi_shared/ssh_keys/$(hostname).pub

    if [[ "$ROLE" == "head" ]]; then
        echo "Waiting for all worker nodes' SSH keys..."

        EXPECTED_NODES=$(grep -vc ^# /mnt/mpi_shared/hostfile)

        end=$((SECONDS+120))
        while [ $SECONDS -lt $end ]; do
            NUM_KEYS=$(ls /mnt/mpi_shared/ssh_keys/*.pub 2>/dev/null | wc -l)
            echo "Found $NUM_KEYS of $EXPECTED_NODES keys..."
            if [ "$NUM_KEYS" -ge "$EXPECTED_NODES" ]; then
                break
            fi
            sleep 5
        done

        if [ "$NUM_KEYS" -lt "$EXPECTED_NODES" ]; then
            echo "ERROR: Timeout waiting for all nodes' SSH keys!"
            exit 1
        fi

        echo "All keys are present. Generating merged authorized_keys..."

        {
            [ -f /home/ubuntu/.ssh/authorized_keys.bak ] && cat /home/ubuntu/.ssh/authorized_keys.bak
            awk '!seen[$0]++' /mnt/mpi_shared/ssh_keys/*.pub
        } > /mnt/mpi_shared/ssh_keys/authorized_keys_all

        cp /mnt/mpi_shared/ssh_keys/authorized_keys_all /home/ubuntu/.ssh/authorized_keys
        chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
        chmod 600 /home/ubuntu/.ssh/authorized_keys
    else
        while [ ! -f /mnt/mpi_shared/ssh_keys/authorized_keys_all ]; do
            echo "Waiting for head node to publish authorized_keys_all..."
            sleep 5
        done

        cp /mnt/mpi_shared/ssh_keys/authorized_keys_all /home/ubuntu/.ssh/authorized_keys
        chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
        chmod 600 /home/ubuntu/.ssh/authorized_keys
    fi
}

echo "=== FINAL CONFIGURATION ==="
{
    cat > /etc/profile.d/mpi.sh <<'EOT'
export PATH="/usr/local/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# OpenMPI Tuning for Virtio
export OMPI_MCA_pml=ob1
export OMPI_MCA_btl="self,tcp,vader"
export OMPI_MCA_btl_tcp_if_exclude="lo,docker0"
export OMPI_MCA_btl_tcp_eager_limit=2M
export OMPI_MCA_btl_tcp_rndv_eager_limit=2M
export OMPI_MCA_btl_tcp_retries=10
export OMPI_MCA_rmaps_base_mapping_policy=core
export OMPI_MCA_hwloc_base_binding_policy=core
EOT
    source /etc/profile.d/mpi.sh
}

echo "=== OCI A2 MPI SETUP COMPLETE ==="
