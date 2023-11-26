#!/bin/bash

# Function to check if the OS is macOS
is_macos() {
    [ "$(uname -s)" == "Darwin" ]
}


######################
#       SETUP        #
######################

#set -euxo pipefail

# Define ANSI color codes for red and reset
GREEN='\033[0;32m' # Green
RED='\033[0;31m' # Red
NC='\033[0m' # No Color

# Check if the filename is given
if [ "$#" -ne 1 ]; then
    echo -e "${RED}[ERROR] No arguments provided, see the example:${NC} ./scripts/k8s_cluster_creation/start_ansible.sh cluster-dev.json"
    exit 1
fi

# Declare variables
MAIN_FOLDER_PATH="$PWD/scripts/k8s_cluster_creation" # Get complete root folder path (/path/to/dale-k8s-infra)
NODES_JSON_PATH="$MAIN_FOLDER_PATH/json/$1" # Complete path of where is located the file json to get node's hostname
NEW_NODE_OR_INIT="INIT"

# Check if the nodes.json file exists
if [ ! -f "$NODES_JSON_PATH" ]; then
    echo -e "${RED}[ERROR] file '$1' not found.${NC}"
    exit 1
fi

# Set $HOME and $PWD before become root
HOME_DIR="$HOME"
PWD_DIR="$PWD"

# Become root
sudo echo "[INFRMATION] HOME user directory path: '$HOME_DIR'"
sudo echo "[INFRMATION] PWD user directory path: '$PWD_DIR'"

##############################################################
# CHECK IF IT IS A CLUSTER INSTALLATION OR ADDING A NEW NODE #
##############################################################

# Read JSON data from the "nodes.json" file
json_data=$(cat "$NODES_JSON_PATH")

# Check if there are nodes to add 
# or is the first cluster configuration
nodes_to_add=$(echo $json_data | jq -c '.nodes_to_add[]')
nodes_to_configure=$(echo $json_data | jq -c '.nodes_to_configure[]')
nodes_to_configure_backup=$nodes_to_configure

# Check if the array is not empty
if [ -n "$nodes_to_add" ]; then
    # If there are new nodes we need to:
    #
    # 1. add on each previous node hosts file,
    #    the new hostname of the new nodes.
    #   
    # 2. Change on yml manifests the hostname string.
    #
    # 3. Create yml manifest for the new nodes
    #
    # END Continuing with the script...
    echo "[INFORMATION] Detected new nodes to add: $nodes_to_add"
    echo "[INFORMATION] There are new nodes to add to the cluster, starting the procedure..."

    # Starting point 1... 
    hostnames_ips=() # Create an array to store hostnames and IPs, new nodes
    hostnames_prev_nodes=() # Declaring the array for prev. nodes 
    path_template_yml=$(echo $json_data | jq -c '.path_vars_file_master_node_ansible') # Template to create new YAML for al lthe new nodes
    path_template_yml="$PWD_DIR/$path_template_yml"

    # Read new nodes to add
    while IFS= read -r node; do
        # Extract IP and hostname
        ip=$(echo "$node" | jq -r '.ip')
        hostname=$(echo "$node" | jq -r '.hostname')

        # Append to the array
        hostnames_ips+=({"\\\"hostname\\\":\\\"$hostname\\\",\\\"ip\\\":\\\"$ip\\\"}")
    done <<< "$nodes_to_add"

    # Compose the string
    hostnames_str="{\\\"hostnames\\\":[$(IFS=,; echo "${hostnames_ips[*]}")]}"

    # Print message
    echo "[INFORMATION] Added on each previous node hosts file, the new hostname of the new nodes."
    echo "[INFORMATION] Hosts to add: $hostnames_str"

    # Starting point 2...
    # In the previous nodes manifests,
    # add the string 'hostnames_str' to the
    # ansible group var manifest of every single node.
    # after the file update, execute the playbook to add
    # on remote worker node the new node.
    while IFS= read -r node; do
        # Get values from json
        file_path=$(echo "$node" | jq -r '.path_vars_ansible_file')
        ssh_user_password=$(echo $node | jq -r '.ssh_user_password')
        path_vars_ansible_file=$(echo $node | jq -r '.path_vars_ansible_file')
        ip=$(echo "$node" | jq -r '.ip')
        hostname=$(echo "$node" | jq -r '.hostname')
        
        # Print msg
        echo "[INFORMATION] Adding new nodes hosts to the node: $hostname - $ip - $hostname"

        # Get the path of the file yaml of the node
        complete_path_yaml="$PWD_DIR/$file_path"
        echo "[INFORMATION] Path of the file to add new nodes: $complete_path_yaml"

        # Update YAML
        modified_string=$(echo "$hostnames_str" | sed 's/\\"/\\\\\\\\\\\\\\"/g') # Convert for YAML format, adding \\\" instead of \"
        # For MacOS is different...
        if is_macos; then
            # macOS
            sed -i '' "s/^new_json_hostnames: .*/new_json_hostnames: \"$modified_string\"/" "$complete_path_yaml"
        else
            # Ubuntu
            sed -i "s/^new_json_hostnames: .*/new_json_hostnames: \"$modified_string\"/" "$complete_path_yaml"
        fi

        # Start the playbook to add new nodes on /etc/hosts
        ansible-playbook -i "$PWD_DIR/ansible/k8s_cluster_creation/inventory/hosts.yml" "$PWD_DIR/ansible/k8s_cluster_creation/playbooks/k8s_add_new_nodes.yml" -e "@$PWD_DIR/$path_vars_ansible_file" --extra-vars "ansible_become_pass=$ssh_user_password" -v

        # Capture the exit status of the ansible-playbook command.
        # '$?' is a special variable that holds the exit status of the last executed command. 
        # The exit status is a numerical value that indicates whether the command executed 
        # successfully (exit status 0) or encountered an error (a non-zero exit status).
        playbook_status=$?

        # Check the exit status and take actions accordingly
        if [[ $playbook_status -eq 0 ]]; then
            echo -e "${GREEN}[INFORMATION] Playbook to add new node ran successfully for the node: $hostname${NC}"
        else
            echo -e "${RED}[ERROR] Playbook to add new node encountered an error for the node: $hostname${NC}"
            exit 1  # Exit the script with an error code
        fi
    
        # Wait for background process (ansible-playbook) to complete
        wait

        # Append to the array
        hostnames_prev_nodes+=("{\\\"hostname\\\":\\\"$hostname\\\",\\\"ip\\\":\\\"$ip\\\"}")
    done <<< "$nodes_to_configure"

    # Concatenate arrays
    merged_array=("${hostnames_ips[@]}" "${hostnames_prev_nodes[@]}")

    # Compose the final output
    final_output="{\\\"hostnames\\\":[$(IFS=,; echo "${merged_array[*]}")]}"
    modified_final_string=$(echo "$final_output" | sed 's/\\"/\\\\\\\\\\\\\\"/g') # Convert for YAML format, adding \\\" instead of \"
    
    # Print message
    echo "[INFORMATION] Need to update YAML field 'node_to_configure' for each node: $modified_final_string"
    echo "[INFORMATION] Updating YAML to remote nodes with the new nodes as hosts."

    # For each prev. node, update YAML file
    while IFS= read -r node; do
        # Get values from json
        file_path=$(echo "$node" | jq -r '.path_vars_ansible_file')
        hostname=$(echo $node | jq -r '.hostname')
        new_json_hosts=""

        # Get the path of the file yaml of the node
        file_path=$(echo "$file_path" | sed 's:/*$::') # Remove trailing slashes from file_path
        complete_path_yaml="$PWD_DIR/$file_path" # Combine with the file path
        echo "[INFORMATION] Updating node: $hostname"
        echo "[INFORMATION] Updating YAML file: $complete_path_yaml"
        
        # Clean the YAML...
        # For MacOS is different...
        if is_macos; then
            # macOS
            sed -i '' "s/^json_hostnames: .*/json_hostnames: \"$modified_final_string\"/" "$complete_path_yaml"
            sed -i '' "s/^new_json_hostnames: .*/new_json_hostnames: \"$new_json_hosts\"/" "$complete_path_yaml"
        else
            # Ubuntu
            sed -i "s/^json_hostnames: .*/json_hostnames: \"$modified_final_string\"/" "$complete_path_yaml"
            sed -i "s/^new_json_hostnames: .*/new_json_hostnames: \"$new_json_hosts\"/" "$complete_path_yaml"
        fi

        sed_status=$? # Sed status

        # Check the exit status and take actions accordingly
        if [[ $sed_status -eq 0 ]]; then
            echo -e "${GREEN}[INFORMATION] Updating YAML (with new hostnames added) of the node: $hostname${NC}"
        else
            echo -e "${RED}[ERROR] An exception occurred during the updates of the YAML about the node: $hostname${NC}"
            exit 1  # Exit the script with an error code
        fi
    
        # Wait for background process (sed) to complete
        wait
    done <<< "$nodes_to_configure"

    # Staring point 3...
    # Now we need to create the YAML for new nodes...
    while IFS= read -r node; do
        # Get values from json
        ansible_host=$(echo "$node" | jq -r '.ansible_host')
        node_type=$(echo "$node" | jq -r '.node_type')
        ssh_username=$(echo "$node" | jq -r '.ssh_username')
        ssh_key_path=$(echo "$node" | jq -r '.ssh_key_path')
        net_ports_conf=$(echo "$node" | jq -r '.net_ports_conf')
        ports_open_method=$(echo "$node" | jq -r '.ports_open_method')
        ssh_user_password=$(echo "$node" | jq -r '.ssh_user_password')
        file_path=$(echo "$node" | jq -r '.path_vars_ansible_file')
        hostname=$(echo "$node" | jq -r '.hostname')
        ip=$(echo "$node" | jq -r '.ip')
        physical_env=$(echo "$node" | jq -r '.physical_env')
        complete_file_path="$PWD_DIR/$file_path"

        # Print message
        echo "[INFORMATION] Creating YAML for the new node: $hostname"

        # Create the new node YAML in the cluster folder
        path_template_node_yml=$(echo $json_data | jq -c '.path_vars_file_master_node_ansible') # Template to create new YAML for al lthe new nodes
        path_template_node_yml="$PWD_DIR/${path_template_node_yml//\"}"
        
        # Print path file
        echo "[INFORMATION] Path template: $path_template_node_yml"
        echo "[INFORMATION] Path where create the new file: $complete_file_path"
        
        # Copy file
        sudo cp "$path_template_node_yml" "$complete_file_path"

        cp_status=$? # cp status

        # Check the exit status and take actions accordingly
        if [[ $cp_status -eq 0 ]]; then
            echo -e "$[INFORMATION] Template YAML copied for the new node: $hostname"
        else
            echo -e "${RED}[ERROR] An exception occurred during the YAML copy of the new node: $hostname${NC}"
            exit 1  # Exit the script with an error code
        fi
    
        # Wait for background process (sed) to complete
        wait

        # Update the values in the YAML copied...
        # For MacOS is different...
        if is_macos; then
            # macOS
            sed -i '' \
                -e "s|^ansible_host: .*|ansible_host: \"$ansible_host\"|" \
                -e "s|^node_type: .*|node_type: \"$node_type\"|" \
                -e "s|^node_ssh_user: .*|node_ssh_user: \"$ssh_username\"|" \
                -e "s|^ssh_private_key_path: .*|ssh_private_key_path: \"$ssh_key_path\"|" \
                -e "s|^required_ports: .*|required_ports: \"$net_ports_conf\"|" \
                -e "s|^open_ports_for_master_or_worker: .*|open_ports_for_master_or_worker: \"$ports_open_method\"|" \
                -e "s|^node_ip: .*|node_ip: \"$ip\"|" \
                -e "s|^env: .*|env: \"$physical_env\"|" \
                -e "s|^node_name: .*|node_name: \"$hostname\"|" \
                "$complete_file_path"
        else
            # Ubuntu
            sed -i \
                -e "s|^ansible_host: .*|ansible_host: \"$ansible_host\"|" \
                -e "s|^node_type: .*|node_type: \"$node_type\"|" \
                -e "s|^node_ssh_user: .*|node_ssh_user: \"$ssh_username\"|" \
                -e "s|^ssh_private_key_path: .*|ssh_private_key_path: \"$ssh_key_path\"|" \
                -e "s|^required_ports: .*|required_ports: \"$net_ports_conf\"|" \
                -e "s|^open_ports_for_master_or_worker: .*|open_ports_for_master_or_worker: \"$ports_open_method\"|" \
                -e "s|^node_ip: .*|node_ip: \"$ip\"|" \
                -e "s|^env: .*|env: \"$physical_env\"|" \
                -e "s|^node_name: .*|node_name: \"$hostname\"|" \
                "$complete_file_path"
        fi

        sed_status=$? # Result of sed

        # Check the exit status and take actions accordingly
        if [[ $sed_status -eq 0 ]]; then
            echo -e "${GREEN}[INFORMATION] New YAML created and updated for the new node: $hostname${NC}"
        else
            echo -e "${RED}[ERROR] An exception occurred during the creation of the YAML about the new node: $hostname${NC}"
            exit 1  # Exit the script with an error code
        fi
    
        # Wait for background process (sed) to complete
        wait
    done <<< "$nodes_to_add"

    # Move the nodes_to_add into nodes_to_configure and set nodes_to_add to an empty array
    json_cluster_path_file="$NODES_JSON_PATH"
    json_input=$(cat "$json_cluster_path_file")

    # Migrate nodes from nodes_to_add to nodes_to_configure and set nodes_to_add to an empty array
    json_output=$(echo "$json_input" | jq '.nodes_to_configure += .nodes_to_add | .nodes_to_add = []')

    # Check status
    jq_status=$?

    # Check the exit status and take actions accordingly
    if [[ $jq_status -eq 0 ]]; then
        echo -e "${GREEN}[INFORMATION] Json updated!${NC}"
    else
        echo -e "${RED}[ERROR] An exception occurred during the updates of the json.${NC}"
        exit 1  # Exit the script with an error code
    fi

    # Save the updated JSON to a file
    echo "$json_output" > "$json_cluster_path_file"

    # Update the value for the variable
    NEW_NODE_OR_INIT="NEW_NODES"

    # Print message
    echo "[INFORMATION] Created new YAML files for the new nodes to add, see the json updated: $json_cluster_path_file"
fi


#########################################
# INSTALL K8S CLUSTER ON PROVIDED NODES #
#########################################

# Print message
echo "[INFORMATION] K8s cluster creation/updates started! Creating and configuring the nodes of the cluster..."

# Extracting values
path_vars_master_node=$(echo $json_data | jq -r '.path_vars_file_master_node_ansible')
ssh_user_password_master_node=$(echo $json_data | jq -r '.ssh_user_password_master_node')
master_node=() # Used for node labeling
workers_nodes=() # Used for node labeling

# Below variables used to setup kubeconfig
BUCKET_NAME=$(echo $json_data | jq -r '.storj_bucket_name')
BUCKET_SECRET=$(echo $json_data | jq -r '.storj_export')
CLUSTER_NAME=$(echo $json_data | jq -r '.cluster_name')
KUBECONFIG_SETUP=$(echo $json_data | jq -r '.kubeconfig_setup')

# Check if new node or init
if [ "$NEW_NODE_OR_INIT" == "NEW_NODES" ]; then
    nodes_to_configure=$nodes_to_add
    KUBECONFIG_SETUP="false"
fi

# Loop through the array
while IFS= read -r node; do
    # Declare loop variables
    node_type=$(echo $node | jq -r '.node_type')
    ssh_user_password=$(echo $node | jq -r '.ssh_user_password')
    path_vars_ansible_file=$(echo $node | jq -r '.path_vars_ansible_file')
    hostname=$(echo $node | jq -r '.hostname')
    echo "-----------------------------------"
    echo "        NODE TO CONFIGURE          "
    echo "-----------------------------------"
    echo "Node Type: $node_type"
    echo "SSH User Password: ***********"
    echo "Path Vars Ansible File: $path_vars_ansible_file"
    echo "Hostname: $hostname"
    echo "-----------------------------------"
    echo "[INFORMATION] Running playbook for the node: $hostname"
    
    # Run the ansible playbook and capture the exit status
    ansible-playbook -i "$PWD_DIR/ansible/k8s_cluster_creation/inventory/hosts.yml" "$PWD_DIR/ansible/k8s_cluster_creation/playbooks/k8s_cluster_creation.yml" -e "@$PWD_DIR/$path_vars_ansible_file" --extra-vars "ansible_become_pass=$ssh_user_password" -v

    # Capture the exit status of the ansible-playbook command.
    playbook_exit_status=$?

    # Check the exit status and take actions accordingly
    if [[ $playbook_exit_status -eq 0 ]]; then
        echo -e "${GREEN}[INFORMATION] Playbook ran successfully for the node: $hostname${NC}"
    else
        echo -e "${RED}[ERROR] Playbook encountered an error for the node: $hostname${NC}"
        exit 1  # Exit the script with an error code
    fi

    # Wait for background process (ansible-playbook) to complete
    wait

    # Add to the array based on the node type
    if [[ "$node_type" == "worker" ]]; then
        workers_nodes+=("$hostname")
    else
        master_node+=("$hostname")
    fi
done <<< "$nodes_to_configure"


######################
#   NODES LABELING   #
######################

# Check if new node or init
if [ "$NEW_NODE_OR_INIT" == "NEW_NODES" ]; then
    while IFS= read -r node; do
        hostname=$(echo $node | jq -r '.hostname')
        node_type=$(echo $node | jq -r '.node_type')

        # Add to the array based on the node type
        if [[ "$node_type" == "worker" ]]; then
            workers_nodes+=("$hostname")
        else
            master_node+=("$hostname")
        fi
    done <<< "$nodes_to_configure_backup" # Using the backup done at start of 'new node procedure'
fi

# Only for master, labels nodes
echo "[INFORMATION] Label nodes (only to execute playbook on master node)"

# Check if master_node is empty and set it to "NO_MASTER" if it is
if [ ${#master_node[@]} -eq 0 ]; then
    master_node+=("NO_MASTER")
fi

# Convert the arrays to JSON-like strings
master_node_str=$(printf '"%s", ' "${master_node[@]}")
workers_nodes_str=$(printf '"%s", ' "${workers_nodes[@]}")

# Remove the trailing comma and space
master_node_str="[${master_node_str%, }]"
workers_nodes_str="[${workers_nodes_str%, }]"

# Formatting master node string
master_node_str=$(echo "$master_node_str" | tr -d ' ' | sed "s/\"/'/g") # Cleaning the string

# Formatting workers nodes string
workers_nodes_str=$(echo "$workers_nodes_str" | tr -d ' ' | sed "s/\"/'/g")  # Remove spaces and replace double quotes with single quotes

# Print message
echo "[INFORMATION] Starting to run the palybook to label th nodes..."
echo "[INFORMATION] Worker nodes: '$workers_nodes_str'"
echo "[INFORMATION] Master nodes: '$master_node_str'"

# Start ansible playbook
ansible-playbook -i "$PWD_DIR/ansible/k8s_cluster_creation/inventory/hosts.yml" "$PWD_DIR/ansible/k8s_cluster_creation/playbooks/k8s_label_nodes.yml" -e "@$PWD_DIR/$path_vars_master_node" --extra-vars "ansible_become_pass=$ssh_user_password_master_node workers_nodes=$workers_nodes_str master_nodes=$master_node_str" -v

playbook_label_exit_status=$?

# Check the exit status and take actions accordingly
if [ $playbook_label_exit_status -eq 0 ]; then
    echo -e "${GREEN}[INFORMATION] Playbook Label Operation completed${NC}"
else
    echo -e "${RED}[ERROR] Playbook label Operation failed${NC}"
    exit 1  # Exit the script with an error code
fi

# Wait for background process (ansible-playbook) to complete
wait

# Print message
echo -e "${GREEN}[INFORMATION] K8s cluster configured successfully, all nodes have been initialized :)${NC}"


##################################################
# KUBECONFIG SETUP ON CURRENT MACHINE (OPTIONAL) #
##################################################

if [ "$KUBECONFIG_SETUP" == "true" ]; then
    # From storj, recover the kubeconfig of the cluster to
    # connect from this machine.
    echo "[INFORMATION] Configure the kubeconfig on the local machine..."

    # Setup storj
    sudo bash -c "echo \"$BUCKET_SECRET\" > export.txt"
    echo "n" | uplink access import --force main export.txt

    # Check if the .kube folder exists or not
    if [ ! -d "$HOME/.kube" ]; then
        # Create the .kube folder
        mkdir -p "$HOME/.kube"
    fi

    # Check if the .kube/config folder exists or not
    if [ ! -d "$HOME/.kube/config" ]; then
        # Create the .kube/config folder
        mkdir -p "$HOME/.kube/config"
    fi

    # Set te path where download kubeconfig
    kubeconfig_path="$HOME/.kube/config/$CLUSTER_NAME/kubeconfig"

    # Store the KUBECONFIG string
    kubeconfig_string=""

    # Read from storj and copy local
    uplink cp "sj://$BUCKET_NAME/$CLUSTER_NAME/admin.conf" "$kubeconfig_path"

    # Update os variable KUBECONFIG...
    # Check if KUBECONFIG is already
    # set and if it contains a non-empty value.
    echo "[INFORMATION] OS KUBECONFIG VARIABLE: $KUBECONFIG"
    if [ -n "$KUBECONFIG" ]; then
        # Append the new kubeconfig path to the existing KUBECONFIG
        kubeconfig_string="$KUBECONFIG:$kubeconfig_path"
    else
        # If KUBECONFIG is empty or unset, set it to the new kubeconfig path
        kubeconfig_string="$kubeconfig_path"
    fi
    
    # Check if macos because the
    # .bashrc on mac is .zshrc
    file_bash_mac_or_ubuntu=""
    if is_macos; then
        # macOS
        file_bash_mac_or_ubuntu="$HOME_DIR/.zshrc"
        echo "[INFORMATION] file bash profile path set for macos: '$file_bash_mac_or_ubuntu'"
    else
        # Ubuntu
        file_bash_mac_or_ubuntu="$HOME_DIR/.bashrc"
        echo "[INFORMATION] file bash profile path set for ubuntu: '$file_bash_mac_or_ubuntu'"
    fi

    # Update the .bashrc or .zshrc
    if grep -q "^KUBECONFIG=" "$file_bash_mac_or_ubuntu"; then
        # If "KUBECONFIG" is already in .bashrc or .zshrc, append the new value
        sudo sed -i "s|^KUBECONFIG=.*|KUBECONFIG=\"$kubeconfig_string\"|" "$file_bash_mac_or_ubuntu"
    else
        # If "KUBECONFIG" is not in .zshrc or .bashrc, add it
        echo "KUBECONFIG=\"$kubeconfig_string\"" | sudo tee -a "$file_bash_mac_or_ubuntu"
    fi

    # Check if there is also 'export KUBECONFIG'
    # on .bashrc or .zshrc, if not add it
    if ! grep -q "export KUBECONFIG" "$file_bash_mac_or_ubuntu"; then
        echo "export KUBECONFIG" >> "$file_bash_mac_or_ubuntu"
    fi

    # Make the variable KUBECONFIG available as OS variable
    source "$file_bash_mac_or_ubuntu"

    # Print message value updated
    echo "[INFORMATION] OS KUBECONFIG VARIABLE UPDATED: $KUBECONFIG"
    
    # Remove export file
    sudo rm -rf export.txt

    # Print message operation completed
    echo "[INFORMATION] If 'kubectl get nodes' does not return the number of nodes on the cluster, maybe you need to run 'export KUBECONFIG' manually. Open the terminal and copy-past this: 'export KUBECONFIG=\"$kubeconfig_string\"'"
    echo -e "${GREEN}[INFORMATION] Kubeconfig configured correctly on the local machine:${NC} $kubeconfig_path"
fi
