#!/bin/bash

# //////////////////////////////////////////////////////////
#   Common setup for all servers (Control Plane and Nodes) /
# //////////////////////////////////////////////////////////

# This command makes the script more robust 
# and it provides detailed debugging output.
# It helps ensure that errors are not ignored,
# uninitialized variables are caught, 
# and the script's behavior is clear and predictable.
set -euxo pipefail


############################################
# Check input arguments                    #
############################################

# Check if all seven arguments are provided
if [ "$#" -ne 8 ]; then
    echo "Usage: $0 <KUBERNETES_VERSION> <CRI_OS> <CRI_VERSION> <REQUIRED_PORTS> <OPEN_PORTS_FOR_MASTER_OR_WORKER> <ENV> <IP> <JSON_HOSTNAMES>"
    echo "Example: ./init_node.sh \"1.28.1-00\" \"xUbuntu_22.04\" \"1.28\" \"true\" \"all\" \"dev\" \"192.168.1.56\" \"{ hostnames: [ { \"hostname\": \"master-1\", \"ip\": \"192.168.1.56\" }, { \"hostname\": \"worker-2\", \"ip\": \"192.168.1.57\" } ] }\""
    exit 1
fi


######################################
# Init                               #
######################################

# Print message
echo "[INFORMATION] Start initialization..."

# Declare variables 
# For debug
# KUBERNETES_VERSION="1.28.2-00"
# CRI_OS="xUbuntu_22.04"
# CRI_VERSION="1.28"
# REQUIRED_PORTS="true"
# OPEN_PORTS_FOR_MASTER_OR_WORKER="master"
# CLUSTER_ENV="prod"
# LOCAL_IP="$(ip -4 route get 8.8.8.8 | head -1 | awk '{print $7}')" # Get the local IP address
# JSON_HOSTNAMES="{ \"hostnames\": [ { \"hostname\": \"master-1\", \"ip\": \"192.168.1.56\" }, { \"hostname\": \"worker-2\", \"ip\": \"192.168.1.57\" } ] }"
KUBERNETES_VERSION="$1" # k8s version
CRI_OS="$2" # cri os
CRI_VERSION="$3" # cri version
REQUIRED_PORTS="$4" # This variable check if is required open ports
OPEN_PORTS_FOR_MASTER_OR_WORKER="$5" # Method of which ports open
CLUSTER_ENV="$6"
LOCAL_IP="$7"
JSON_HOSTNAMES="$8"

# No args variables
REPO_PACKAGES_URL="http://packages.dalecosta.com/repo/dale-k8s-packages" # Repository of the packages to install
k8s_v="" # Used to set and get GPG key for k8s

# Print message OK
echo "[INFORMATION] Initialization completed!"


#######################################################
# Adding others hostnames to file hosts               #
#######################################################

# Parse the JSON string array using jq
nodes=$(echo "$JSON_HOSTNAMES" | jq -c '.hostnames[]')

# Special variable which allow you to capture
# the status of the previous operation,
# in this case the operation to convert a json
valid_json=$?

# Check if json is valid
if [[ $valid_json -eq 0 ]]; then
    echo "[INFORMATION] The json passed by arguments is correct (new nodes), start to add hostnames to /etc/hosts..."
else
    echo "[ERROR] The json passed by arguments is not correct (new nodes), see: $JSON_HOSTNAMES"
    exit 1  # Exit the script with an error code
fi

# Append new line --> '192.168.1.56 master-1'
# to file /etc/hosts
# Extract hostnames and IPs from JSON
for node in $nodes; do
    hostname=$(echo $node | jq -r '.hostname')
    ip=$(echo $node | jq -r '.ip')
    echo "$ip $hostname" | sudo tee -a /etc/hosts
done

echo "[INFORMATION] Hostnames added correctly!"


#######################################################
# Ports opening based on environment and requirements #
#######################################################

# Open required ports if configured
if [ "$REQUIRED_PORTS" == "true" ]; then
    # Print message start stage
    echo "[INFORMATION] Starting to open ports..."
    
    # Open required ports:
    # - master: configuring ports for master
    # - worker: configuring ports for worker
    # - all: open all ports (TCP/UPD)
    # - both: open master and worker ports
    #
    # K8S PORTS
    # |-------------------------------------------------------------|
    # |       SERVICE NAME      |   PORT     |   MASTER  |   WORKER |
    # |-------------------------------------------------------------|  
    # | kube-apiserver          |   6443     |    YES    |   NO     |
    # | kubelet                 |   10250    |    YES    |   YES    |  
    # | kube-scheduler          |   10259    |    YES    |   NO     |
    # | kube-controller-manager |   10257    |    YES    |   NO     |
    # | etcd                    | 2379-2380  |    YES    |   NO     |   
    # | kube-proxy              |   10256    |    YES    |   YES    |
    # | nodePort services       | 30000-32767|    NO     |   YES    |
    # |-------------------------------------------------------------|
    # ref: https://kubernetes.io/docs/reference/networking/ports-and-protocols/
    #
    # CALICO
    # |--------------------------------------------------------------------------------------------------------------------------------------|  
    # | Configuration                                       | Host(s)             | Connection Type | Port/Protocol                          |
    # |-----------------------------------------------------|---------------------|-----------------|----------------------------------------|
    # | Calico networking (BGP)                             | All                 | Bidirectional   | TCP 179                                |
    # | Calico networking with IP-in-IP enabled (default)   | All                 | Bidirectional   | IP-in-IP, often represented by itself  |
    # | Calico networking with VXLAN enabled                | All                 | Bidirectional   | UDP 4789                               |
    # | Calico networking with Typha enabled                | Typha agent hosts   | Incoming        | TCP 5473 (default)                     |
    # | Calico networking with IPv4 Wireguard enabled       | All                 | Bidirectional   | UDP 51820 (default)                    |
    # | Calico networking with IPv6 Wireguard enabled       | All                 | Bidirectional   | UDP 51821 (default)                    |
    # | flannel networking (VXLAN)                          | All                 | Bidirectional   | UDP 4789                               |
    # | All                                                 | kube-apiserver host | Incoming        | Often TCP 443 or 6443*                 |
    # | etcd datastore                                      | etcd hosts          | Incoming        | Officially TCP 2379 but can vary       |
    # |--------------------------------------------------------------------------------------------------------------------------------------|
    # ref: https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements

    sudo ufw --force enable # Enable firewall with iptables
    
    # Opens ports 443, 8080, 6443, 4443 and 22 for ssh
    sudo ufw allow 22/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 8080/tcp
    sudo ufw allow 6443
    sudo ufw allow 4443
    # For dev env, open also 8081, 5000, 5001
    if [[ "$CLUSTER_ENV" == "dev" ]]; then
        sudo ufw allow 8081/tcp
        sudo ufw allow 5000/tcp
        sudo ufw allow 5001/tcp
    fi

    if [[ "$OPEN_PORTS_FOR_MASTER_OR_WORKER" == "master" ]] ||
       [[ "$OPEN_PORTS_FOR_MASTER_OR_WORKER" == "both" ]]; then
        # Open ports required for the master node
        # - kube-apiserver, 
        # - kubelet,
        # - kube-scheduler, 
        # - kube-controller-manager,
        # - etcd
        sudo ufw allow 10250
        sudo ufw allow 10259
        sudo ufw allow 10257
        sudo ufw allow 2379:2380/tcp
        # - kube-proxy is for both master and worker
        sudo ufw allow 10256
    fi

    if [[ "$OPEN_PORTS_FOR_MASTER_OR_WORKER" == "worker" ]] ||
       [[ "$OPEN_PORTS_FOR_MASTER_OR_WORKER" == "both" ]]; then
        # Open ports required for the worker node
        # - kubelet, 
        # - kube-proxy, 
        # - kube-apiserver,
        # - nodePort services
        sudo ufw allow 10250
        sudo ufw allow 10256
        sudo ufw allow 6443
        sudo ufw allow 30000:32767/tcp
    fi

    if [[ "$OPEN_PORTS_FOR_MASTER_OR_WORKER" == "all" ]]; then
        sudo ufw allow 1:65535/tcp && sudo ufw allow 1:65535/udp
    fi

    if [[ "$OPEN_PORTS_FOR_MASTER_OR_WORKER" != "all" ]]; then
        # Open Calico ports
        sudo ufw allow 179 # Calico networking (BGP)
        sudo ufw allow 4789/udp # Calico networking with VXLAN enabled
        sudo ufw allow 5473 # Calico networking with Typha enabled
        sudo ufw allow 51820/udp # Calico networking with IPv4 Wireguard enabled
        sudo ufw allow 51821/udp # Calico networking with IPv6 Wireguard enabled
    fi
    
    # Print verbose message to see ports
    sudo ufw status verbose
else
    # Print message ports are not required to open
    echo "[INFORMATION] Ports are not required to be opened... Continuing with the procedure..."
fi

# disable swap
sudo swapoff -a

# keeps the swapoff during reboot
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab - || true
sudo apt-get update -y


######################################
# Install CRI-O Runtime              #
######################################

# ref: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

# Print message
echo "[INFORMATION] Start to install cri-o (CRI runtime)..."

# Create the .conf file to load the modules at bootup to
# fowardIPv4 and letting iptables see bridged traffic
cat <<EOF | sudo tee /etc/modules-load.d/crio.conf
overlay
br_netfilter
EOF

# These commands are used to load specific kernel modules 
# (overlay and br_netfilter) into the Linux kernel, enabling 
# certain features related to filesystems (overlayfs) and network 
# filtering (bridge networking). These modules need to be loaded to use 
# the associated functionality in the Linux kernel. The use cases for 
# these modules may include containerization, network virtualization
# and firewall configuration, among others
sudo modprobe overlay
sudo modprobe br_netfilter

# Sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Reload the sysctl settings system-wide
sudo sysctl --system

# Set the local repo
REPO_CRI_OS_URL="$REPO_PACKAGES_URL/apt/opensuse/v$CRI_VERSION/cri_os/download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$CRI_OS"
REPO_CRI_O_URL="$REPO_PACKAGES_URL/apt/opensuse/v$CRI_VERSION/cri_o/download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRI_VERSION/$CRI_OS"

# Add a package repository for cri-o to /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
# $CRI_OS and $CRI_VERSION should be defined earlier in the script
## ORIGINAL
## cat <<EOF | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
## deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$CRI_OS/ /
## EOF
cat <<EOF | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
deb [trusted=yes] "$REPO_CRI_OS_URL/" /
EOF

# Add another package repository for cri-o with a specific version to /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$CRI_VERSION.list
## ORIGINAL
## cat <<EOF | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$CRI_VERSION.list
## deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRI_VERSION/$CRI_OS/ /
## EOF
cat <<EOF | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$CRI_VERSION.list
deb [trusted=yes] "$REPO_CRI_O_URL/" /
EOF

# Download the GPG key for th repositories and add it to the trusted GPG keys
## ORIGINAL
## curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$CRI_OS/Release.key | sudo apt-key --keyring /etc/apt/trusted.gpg.d/libcontainers.gpg add -
## curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$CRI_VERSION/$CRI_OS/Release.key | sudo apt-key --keyring /etc/apt/trusted.gpg.d/libcontainers.gpg add -
curl -k -L "$REPO_CRI_OS_URL/Release.key" | sudo apt-key --keyring /etc/apt/trusted.gpg.d/libcontainers.gpg add -
curl -k -L "$REPO_CRI_O_URL/Release.key" | sudo apt-key --keyring /etc/apt/trusted.gpg.d/libcontainers.gpg add -

# Update the package database to include the newly added repositories
sudo apt-get update

# Install the cri-o and cri-o-runc packages
sudo apt-get install cri-o cri-o-runc -y

# Reload the systemd daemon to recognize the new service unit files
sudo systemctl daemon-reload

# Enable and start the cri-o service
sudo systemctl enable crio --now

# Print message OK
echo "[INFORMATION] CRI runtime installed susccessfully"


########################################
# Install kubelet, kubectl and Kubeadm #
########################################

# ref: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

# print msg
echo "[INFORMATION] Starting to install kubelet, kubectl and Kubeadm..."

# Update the package list to get the latest package information and
# install necessary packages for working with Kubernetes
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl || true

# Create keyring folder if there isn't
sudo mkdir -p -m 755 /etc/apt/keyrings

# Print msg k8s version
echo "[INFORMATION] K8s version to install: $KUBERNETES_VERSION"

# Get only the firsts two numbers from k8s version
case $KUBERNETES_VERSION in
    "1.28.2-00" | "1.28.4-1.1")
        k8s_v="1.28"
        ;;
    *)
        echo "[ERROR] Unsupported Kubernetes version: $KUBERNETES_VERSION"
        exit 1
        ;;
esac

# Get and set GPG key
if [ "$KUBERNETES_VERSION" == "1.28.2-00" ]; then
    sudo curl -k -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg "$REPO_PACKAGES_URL/apt/google/key/apt_key.gpg"
else
    sudo curl -fsSL "https://pkgs.k8s.io/core:/stable:/v$k8s_v/deb/Release.key" | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
fi

# Add Kubernetes repository to package sources 
# with the previously downloaded GPG key
if [ "$KUBERNETES_VERSION" == "1.28.2-00" ]; then
    repo_entry="deb [trusted=yes signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] $REPO_PACKAGES_URL/apt/google/v$KUBERNETES_VERSION/packages.cloud.google.com/apt kubernetes-xenial main"
    echo "$repo_entry" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
else
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$k8s_v/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
fi 

# Update the package list again
# to include the Kubernetes repository
sudo apt-get update -y || true

# Install specific versions of 
# kubelet, kubectl, and kubeadm based
# on $KUBERNETES_VERSION
sudo apt-get install -y kubelet="$KUBERNETES_VERSION" kubectl="$KUBERNETES_VERSION" kubeadm="$KUBERNETES_VERSION"

# - Update the package list after 
# installing Kubernetes components
sudo apt-get update -y || true

# Create or update the /etc/default/kubelet 
# configuration file with the 'KUBELET_EXTRA_ARGS' setting
sudo bash -c "cat > /etc/default/kubelet << EOF
KUBELET_EXTRA_ARGS=--node-ip=$LOCAL_IP
EOF"

# Print message OK
kubelet_v=$(sudo kubelet --version)
kubeadm_v=$(sudo kubeadm version)
kubectl_v=$(sudo kubectl version --client)
echo -e "[INFORMATION] $kubelet_v (kubelet)"
echo -e "[INFORMATION] $kubeadm_v"
echo -e "[INFORMATION] $kubectl_v (kubectl)"
echo "[INFORMATION] kubelet, kubeadm and kubectl installed susccessfully!"
