#!/bin/bash
# Licensed Materials - Property of IBM
# 5737-E67
# @ Copyright IBM Corporation 2016, 2018 All Rights Reserved
# US Government Users Restricted Rights - 
# Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# Author: Brian McSheehy <bmcshee@us.ibm.com>
# 
# * This installer is only certified to work with Ubuntu 16.04x 
# * The recommended minimum configuration for an ICP CE instance is 16 Core x 32 GB RAM x 25 GB Storage


TARGET_OS='Ubuntu 16.04.*'
PYTHON_VERSION='2.7'
VM_MAX_MAP_COUNT_SET='262144'
HOSTNAME=$(/bin/hostname)
IP_ADDR=$(ip route get 1 | awk '{print $NF;exit}')

PROGNAME=$(basename $0)

APT=/usr/bin/apt-get

function error_exit
{
    echo "Error: ${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
    exit 1
}

echo "************************************************"
echo "         Starting IBM ICP-CE Installer          "
printf "************************************************\n\n"


# Check for OS Compatability
OS_CHECK=$(grep -c "$TARGET_OS" /etc/issue)

if [ $OS_CHECK != 1 ]; then
    error_exit "$LINENO: Unsupported operating system"
else
    printf "OS Compatability check \t[ OK ]\n"
fi


# Update APT repo
echo "Updating aptitude repositories"

$APT update

if [ -f /usr/bin/python ]; then
    PYTHON_V=`python -c "import sys;t='{v[0]}.{v[1]}'.format(v=list(sys.version_info[:2]));sys.stdout.write(t)";`

    if [ $PYTHON_V != $PYTHON_VERSION ]; then
        echo "Python $PYTHON_VERSION not found - installing"
        $APT install -y python
    else
        printf "Python $PYTHON_VERSION detected \t[ OK ]\n"
    fi

else
    echo "Python $PYTHON_VERSION not found - installing"
    $APT install -y python
fi


# Update sysctl vm.max_map_count

vm_max_map_count=$(sysctl vm.max_map_count | awk -F= '{print $2}' | tr -d '[:space:]')

if [ $vm_max_map_count != $VM_MAX_MAP_COUNT_SET ]; then
    echo "setting sysctl vm.max_map_count -> $VM_MAX_MAP_COUNT_SET"
    echo "vm.max_map_count=$VM_MAX_MAP_COUNT_SET" | tee -a /etc/sysctl.conf
    /sbin/sysctl -w vm.max_map_count=$VM_MAX_MAP_COUNT_SET
else
    printf "VM MAX MAP COUNT \t[ OK ]\n"
fi


# Update sysctl net.ipv4.ip_local_port_range

IPV4_PORT_RANGE=$(grep -c "^net.ipv4.ip_local_port_range" /etc/sysctl.conf)

if [ $IPV4_PORT_RANGE == 0 ]; then
    echo "setting sysctl net.ipv4.ip_local_port_range -> 10240  60999"
    echo 'net.ipv4.ip_local_port_range="10240 60999"' | tee -a /etc/sysctl.conf
    /sbin/sysctl -w net.ipv4.ip_local_port_range="10240  60999"
else
    printf "IPV4 Port Range \t[ OK ]\n"
fi


# Install Docker Support

if [ ! -f /usr/bin/docker ]; then
    echo "Docker Not Found - Installing Docker Support"
    /usr/bin/curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    /usr/bin/add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    $APT update
    $APT install -y docker-ce
else
    printf "Docker installation check \t[ OK ]\n"
fi


# Install IBM-ICP CE

echo "Installing IBM ICP-CE Docker Package"

docker pull ibmcom/icp-inception:2.1.0.2

[ -d /opt/ibm-cloud-private-ce-2.1.0.2/ ] || mkdir /opt/ibm-cloud-private-ce-2.1.0.2/
cd /opt/ibm-cloud-private-ce-2.1.0.2/
docker run -e LICENSE=accept -v "$(pwd)":/data ibmcom/icp-inception:2.1.0.2 cp -r cluster /data


# Configure SSH Keys

if [ ! -f /root/.ssh/id_rsa ]; then
    echo "Generating SSH KEYS"
    cd /root/.ssh/ || exit 1
    cat /dev/zero | /usr/bin/ssh-keygen -q -N "" || exit 1
    cat id_rsa.pub >> authorized_keys || exit 1
    cp id_rsa /opt/ibm-cloud-private-ce-2.1.0.2/cluster/ssh_key || exit 1
else
    echo "before"
    cat /opt/ibm-cloud-private-ce-2.1.0.2/cluster/ssh_key
    cp /root/.ssh/id_rsa /opt/ibm-cloud-private-ce-2.1.0.2/cluster/ssh_key || exit 1
    echo "after"
    cat /opt/ibm-cloud-private-ce-2.1.0.2/cluster/ssh_key
    printf "SSH Key configuration \t[ OK ]\n"
fi


# Configure /etc/hosts

IP_ADDR_LISTED=$(grep -c $IP_ADDR /etc/hosts)

if [ $IP_ADDR_LISTED == 0 ]; then
    echo "Configuring /etc/hosts"
    printf "$IP_ADDR\t$HOSTNAME\n\n" >> /etc/hosts
else
    printf "/etc/hosts configuration \t[ OK ]\n"
fi

# Configure Ansible hosts file

cat << EOF > /opt/ibm-cloud-private-ce-2.1.0.2/cluster/hosts
[master]
$IP_ADDR

[worker]
$IP_ADDR

[proxy]
$IP_ADDR

#[management]
# 127.0.0.1

#[va]
#5.5.5.5

EOF

# Run Kubernetes Installer
printf "Running Kubernetes Installer...\n\n"
cd /opt/ibm-cloud-private-ce-2.1.0.2/cluster/ || exit 1
docker run -e LICENSE=accept --net=host -t -v "$(pwd)":/installer/cluster ibmcom/icp-inception:2.1.0.2 install

