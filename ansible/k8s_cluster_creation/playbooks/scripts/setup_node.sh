#!/bin/bash

# //////////////////////////////////////////////////////////
#   Setup Node                                             /
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

# Check if provided the type of node
if [[ "$1" == "" ]]; then
    echo "Error, provide the node type (worker or master)"   
    exit 1
fi

# Check if all arguments are provided
if [[ "$#" != 8 ]]; then
    echo "Usage for master node: $0 <NODE_TYPE> <NODENAME> <CLUSTER_NAME> <BUCKET_NAME> <STORJ_SECRET> <NODE_IP> <POD_CIDR> <HOME_DIRECTORY>"
    echo "Example: ./setup_node.sh \"master\" \"k8s-master-node-1-1-srv1\" \"dale-prod\" \"dale-k8s-infra\" \"XYZ1234\" \"192.168.1.45\" \"10.244.0.0/16\" \"/home/dalecosta/\""
    exit 1
fi


############################################
# Init                                     #
############################################

# Declare variables
# For debug
#NODE_TYPE="master"
#NODENAME=$(hostname -s)
#BUCKET_SECRET="1z7iraMTbV81wbHXbi93hi4SSTJafS3rzhHvnsiFupHjuWe8Gz6wekcwi3Usj7HiDg3jR2oaKgFC5KJWzEMX6cNfBGazyR7rEPG9gy5CuHBJPnqX2qMeUmhMdKSadDJH4SJyaXUjWtV8DNiHdiHn5kZZVzvHYFAYgZJYSt6PTaeKjHBQ6yek8LJFEAPLKJgchq4g9WkK9dZXj8wXQESARNGDRqUuUNoJv5pXdTgsNXuVs9r4xTJyLj19pC2LELxDsSUZpUg3C6mWes8vVy37RmwjTwKcewD"
#NODE_IP="192.168.3.234"
#POD_CIDR="10.244.0.0/16"
#BUCKET_NAME="dale-k8s-infra"
#CLUSTER_NAME="dale-dev"
#HOME_DIRECTORY="$HOME"
NODE_TYPE="" # The node is worker or master
NODENAME="" # Node name
BUCKET_SECRET="" # Secret to connect to the bucket storj
NODE_IP="" # Ip of the node
POD_CIDR="" # POD CIDR
BUCKET_NAME="" # Name of the bucket to save k8s file
CLUSTER_NAME="" # Name of the cluster you are going to create
HOME_DIRECTORY="" # Path of $HOME to download and save temporary files

# Variables not set from args
kubeadm_output="" # Variable used to get the output of kubeadm command to store info about master node

# Populate variables with args
NODE_TYPE="$1"
NODENAME="$2"
CLUSTER_NAME="$3"
BUCKET_NAME="$4"
BUCKET_SECRET="$5"
NODE_IP="$6"
POD_CIDR="$7"
HOME_DIRECTORY="$8"


############################################
# Setup node (master or worker)            #
############################################

if [[ "$NODE_TYPE" == "master" ]]; then

    ############################################
    # Setup for control plane (master node)    #
    ############################################

    # Pull required images
    sudo kubeadm config images pull

    # Initialize kubeadm based on PUBLIC_IP_ACCESS
    kubeadm_output=$(sudo kubeadm init --apiserver-advertise-address="$NODE_IP" --apiserver-cert-extra-sans="$NODE_IP" --pod-network-cidr="$POD_CIDR" --node-name "$NODENAME" --ignore-preflight-errors Swap)

    # Change the cluster name of the kubeconfig (admin.config),
    # check if the Kubernetes configuration file exists
    if [ -f "/etc/kubernetes/admin.conf" ]; then
        new_cluster_name="$CLUSTER_NAME"
        kubeconfig_path="/etc/kubernetes/admin.conf"

        # Update the cluster name in the 'clusters' e 'contexts' sections
        sudo sed -i "s/^    name: kubernetes$/    name: $new_cluster_name/" "$kubeconfig_path"
        sudo sed -i "s/cluster: kubernetes/cluster: $new_cluster_name/g" "$kubeconfig_path"
        sudo sed -i "s/kubernetes-admin@kubernetes$/kubernetes-admin@$new_cluster_name/" "$kubeconfig_path"
        # Cleaning the .kubeconfig
        sudo sed -i "s/name: kubernetes/name: $new_cluster_name/g" "$kubeconfig_path"
        sudo sed -i "s/- name: $new_cluster_name-admin/- name: kubernetes-admin/g" "$kubeconfig_path"
        sudo sed -i "s/name: $new_cluster_name-admin@$new_cluster_name/name: kubernetes-admin@$new_cluster_name/g" "$kubeconfig_path"

        echo "[INFORMATION] Kubernetes cluster name and context updated with cluster name '$new_cluster_name'"
    else
        echo "[INFORMATION] Kubernetes configuration file not found at '/etc/kubernetes/admin.conf'"
    fi

    # Extract the required informations using grep
    # This infos will be used by workers to join on cluster
    ip=$(echo "$kubeadm_output" | grep -oP 'kubeadm join \K[^:]+(?=:)')
    token=$(echo "$kubeadm_output" | grep -oP 'token \K[^ ]+')
    cert_hash=$(echo "$kubeadm_output" | grep -oP 'sha256:\S+')

    # Create and save infos on JSON file
    echo "{\"ip\":\"$ip\",\"token\":\"$token\",\"cert\":\"$cert_hash\"}" > "$HOME_DIRECTORY/output_kubeadm.json"

    # Configure kubeconfig
    # (mkdir -p $HOME_DIRECTORY/.kube) # --> Done by ansible
    sudo cp -i /etc/kubernetes/admin.conf $HOME_DIRECTORY/.kube/config
    # sudo chown $(id -u):$(id -g) $HOME_DIRECTORY/.kube/config # --> Done by ansible
    # Configuring kube commands also for root user
    sudo mkdir -p /root/.kube && sudo cp $HOME_DIRECTORY/.kube/config /root/.kube/config && sudo chown root:root /root/.kube/config

    # Install Calico Network (Plugin Network)  
    # tigera-operator
    # original --> https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml  
    sudo kubectl create -f "$HOME_DIRECTORY"/tigera_operator.yml
    
    # Custom resources
    # original --> https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml
    # Use sed to replace the CIDR in the 
    # YAML file with the value of POD_CIDR variables
    sudo sed -i "s|10.244.0.0/16|$POD_CIDR|g" "$HOME_DIRECTORY/custom_resources.yml"
    sudo kubectl create -f "$HOME_DIRECTORY"/custom_resources.yml # Create pods

    # Setup storj
    sudo bash -c "echo \"$BUCKET_SECRET\" > export.txt"
    echo "n" | uplink access import --force main export.txt

    # Copy the json and the "/etc/kubernetes/admin.conf"
    # so then, wokers can download the configurations to join on cluster
    uplink cp --parallelism 10 output_kubeadm.json "sj://$BUCKET_NAME/$CLUSTER_NAME/output_kubeadm.json"
    uplink cp --parallelism 10 "$HOME_DIRECTORY"/.kube/config "sj://$BUCKET_NAME/$CLUSTER_NAME/admin.conf"
else

    ############################################
    # Setup for worker node                    #
    ############################################

    # Setup storj
    sudo bash -c "echo \"$BUCKET_SECRET\" > export.txt"
    echo "n" | uplink access import --force main export.txt

    # Read from storj
    uplink cp "sj://$BUCKET_NAME/$CLUSTER_NAME/output_kubeadm.json" .
    uplink cp "sj://$BUCKET_NAME/$CLUSTER_NAME/admin.conf" .
    
    # Configure kubeconfig
    # (mkdir -p $HOME_DIRECTORY/.kube) # --> Done by ansible
    sudo cp admin.conf /etc/kubernetes # only for workers
    sudo cp -i /etc/kubernetes/admin.conf $HOME_DIRECTORY/.kube/config
    # sudo chown $(id -u):$(id -g) $HOME_DIRECTORY/.kube/config # --> Done by ansible
    # Configuring kube commands also for root user
    sudo mkdir -p /root/.kube && sudo cp $HOME_DIRECTORY/.kube/config /root/.kube/config && sudo chown root:root /root/.kube/config

    # Read the JSON data from the file
    json_data=$(cat output_kubeadm.json)

    # Parse the JSON data using jq and extract the values
    ip=$(echo "$json_data" | jq -r '.ip')
    token=$(echo "$json_data" | jq -r '.token')
    cert_hash=$(echo "$json_data" | jq -r '.cert')

    # Join to master node
    sudo kubeadm join "$ip":6443 --token "$token" --discovery-token-ca-cert-hash "$cert_hash"
fi

# Cleaning
sudo rm -rf export.txt
sudo rm -rf output_kubeadm.json
sudo rm -rf .wget-hsts
sudo find . -type f -name "go*.tar.gz" -exec rm -f {} \;
sudo find . -type f -name "wget*" -exec rm -f {} \;
sudo rm -rf /tmp/terraform_*.zip
sudo rm -rf /tmp/storj-cli.zip

# Print ok message
echo "[INFORMATION] Node initialized correctly, operation successfully completed :)"
