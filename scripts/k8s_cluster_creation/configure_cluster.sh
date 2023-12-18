#!/bin/bash

#set -euxo pipefail

# Define ANSI color codes for red and reset
GREEN='\033[0;32m' # Green
RED='\033[0;31m' # Red
NC='\033[0m' # No Color

######################
#     FUNCTIONS      #
######################

# Function to check if the OS is macOS
is_macos() {
    [ "$(uname -s)" == "Darwin" ]
}

# This fucntion start the playbook
# to configure a node of the k8s cluster
start_playbook_nodes() {
    local ia_hosts=$1
    local ia_path_playbook=$2
    local ia_path_vars_ansible_file=$3
    local ia_ssh_become_password=$4

    # Run the ansible playbook and capture the exit status
    ansible-playbook -i "$ia_hosts" "$ia_path_playbook" -e "$ia_path_vars_ansible_file" --extra-vars "$ia_ssh_become_password" -v

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
}

# Function used to get master nodes to configure on haproxy
create_master_nodes_json() {
    local nodes_c=$1

    # Find master nodes to add on haproxy
    local m_nodes=$(echo "$nodes_c" | jq -c '[.[] | select(.node_type == "master")]')
    
    # Create a new JSON string with only hostname and ip for each node
    local filtered_master_nodes=$(echo "$m_nodes" | jq -c '[.[] | {hostname: .hostname, ip: .ip}]')

    # Begin the JSON array
    local master_nodes_json="["

    # Convert the filtered master nodes JSON string to a Bash array
    local master_node_array=()
    readarray -t master_node_array < <(echo "$filtered_master_nodes" | jq -c '.[]')

    # Loop through each node in the Bash array
    for node in "${master_node_array[@]}"; do
        # Append this node to the JSON array, followed by a comma
        master_nodes_json+="$node,"
    done

    # Remove the last comma and close the JSON array
    master_nodes_json="${master_nodes_json%,}]"

    # Output the final JSON string
    echo "$master_nodes_json"
}

# Function used to setup or update haproxy
start_playbook_haproxy() {
    local i_haproxy_enabled=$1
    local i_nodes_to_add_backup=$2
    local i_json_data=$3
    local i_vip=$4
    local i_ssl_enabled=$5
    local i_dns=$6
    local i_dns_or_ip=$7
    local i_pwd=$8
    local i_json_path=$9

    # Check if HAProxy is enabled
    if [ "$i_haproxy_enabled" == "true" ]; then
        echo "[INFORMATION] HAProxy script is enabled. Reading configuration..."

        # Extract and display properties of each HAProxy instance to configure
        nodes_to_configure=$(echo $i_json_data | jq '.nodes_to_configure[]')

        # Populate variables
        script_name_str=""
        m_nodes_json=""
        add_or_configure=""
        haproxy_nodes=()
        haproxy_to_configure=$(echo $i_json_data | jq -r ".haproxy.haproxy_to_configure[]") 
        haproxy_to_add=$(echo $i_json_data | jq -r ".haproxy.haproxy_to_add[]") 

        # Check if there are new nodes to add
        # or it is first time to configure the HAProxy.
        # This is used to check which master nodes of the k8s are to be taken...
        # From 'nodes_to_configure' or 'i_nodes_to_add_backup'. 
        if [ "$i_nodes_to_add_backup" -ge 1 ]; then
            # update.sh
            script_name_str="update.sh"
            m_nodes_json=$(create_master_nodes_json "$i_nodes_to_add_backup")
            echo "[INFORMATION] Executing 'update.sh' on remotes haproxy..."
            echo "[INFORMATION] There are items in 'nodes_to_add', Start to update haproxy with new master nodes (new nodes added)..."
        else
            # setup.sh
            script_name_str="setup.sh"
            m_nodes_json=$(create_master_nodes_json "$nodes_to_configure")
            echo "[INFORMATION] Executing 'setup.sh' on remotes haproxy..."
            echo "[INFORMATION] There are items in 'nodes_to_configure', Start to configure the HAProxy (first time)..."
        fi

        # Check if there are new HAProxy to add
        # or it is first time configuration.
        # This because the script is the same but
        # the haproxy nodes are different.
        # If you want add new haproxy, we  need to get from 'haproxy_to_add'.
        # If you want configure the first time, we need to get from 'haproxy_to_configure'.
        if [ "$haproxy_to_add" -ge 1 ]
            $haproxy_nodes=$haproxy_to_add
            add_or_configure="haproxy_to_add"
        else 
            $haproxy_nodes=$haproxy_to_configure
            add_or_configure="haproxy_to_configure"
        fi

        # Process the items in 'haproxy_nodes' as needed
        for ((i=0; i<$haproxy_nodes; i++))
        do
            echo "[INFORMATION] HAProxy $((i+1)):"
            echo ""
            p_hostname=$(echo $i_json_data | jq -r ".haproxy.$add_or_configure[$i].hostname")        
            p_lan_interface=$(echo $i_json_data | jq -r ".haproxy.$add_or_configure[$i].lan_interface")
            p_ip_adr=$(echo $i_json_data | jq -r ".haproxy.$add_or_configure[$i].ip")
            p_state=$(echo $i_json_data | jq -r ".haproxy.$add_or_configure[$i].state")
            p_router_id=$(echo $i_json_data | jq -r ".haproxy.$add_or_configure[$i].router_id")
            p_priority=$(echo $i_json_data | jq -r ".haproxy.$add_or_configure[$i].priority")
            p_ssh_endpoint=$(echo $i_json_data | jq -r ".haproxy.$add_or_configure[$i].ssh_endpoint")
            p_ssh_username=$(echo $i_json_data | jq -r ".haproxy.$add_or_configure[$i].ssh_username")
            p_ssh_password=$(echo $i_json_data | jq -r ".haproxy.$add_or_configure[$i].ssh_password")
            p_ssh_key_path=$(echo $i_json_data | jq -r ".haproxy.$add_or_configure[$i].ssh_key_path")
            p_physical_env=$(echo $i_json_data | jq -r ".haproxy.$add_or_configure[$i].physical_env")
            p_internal_or_external=$(echo $i_json_data | jq -r ".haproxy.$add_or_configure[$i].internal_or_external")                
            echo "-----------------------------------"
            echo "             HAPROXY               " 
            echo "-----------------------------------"
            echo "  Hostname: $p_hostname"
            echo "  LAN Interface: $p_lan_interface"
            echo "  IP: $p_ip_adr"
            echo "  State: $p_state"
            echo "  Router ID: $p_router_id"
            echo "  Priority: $p_priority"
            echo "  SSH Endpoint: $p_ssh_endpoint"
            echo "  SSH Username: $p_ssh_username"
            echo "  SSH Password: *******"
            echo "  SSH Key Path: $p_ssh_key_path"
            echo "  Physical Environment: $p_physical_env"
            echo "  Internal or External: $p_internal_or_external"
            echo "-----------------------------------"
            echo ""
            # Update the json moving the haproxy_to_add into haproy_to_configure
            json_str="{
                \"ssl\": {
                    \"enabled\": \"$i_ssl_enabled\",
                    \"dns_or_ip\": \"$i_dns_or_ip\",
                    \"dns\": \"$i_dns\"
                },
                \"haproxy\": {
                    \"hostname\": \"$p_hostname\",
                    \"lan_interface\": \"$p_lan_interface\",
                    \"ip\": \"$p_ip_adr\",
                    \"state\": \"$p_state\",
                    \"router_id\": \"$p_router_id\",
                    \"priority\": \"$p_priority\",
                    \"password\": \"$p_ssh_password\",
                    \"vip\":\"$i_vip\"
                },
                \"master_nodes\": $m_nodes_json           
            }"

            # Execute the Ansible playbook
            echo "[INFORMATION] Running Ansible playbook for HAProxy instance: $hostname"
            ansible-playbook "$i_pwd/ansible/k8s_cluster_creation/playbooks/k8s_execute_bash_script.yml" --extra-vars "local_path_git=$i_pwd" --extra-vars "script_name=$script_name_str" --extra-vars "input_json=$json_str" --extra-vars "target_hosts=$p_ip_adr ansible_user=$p_ssh_username ansible_become_pass=$p_ssh_password" --extra-vars "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"
            p_playbook_status=$?

            # Check the exit status and take actions accordingly
            if [[ $p_playbook_status -eq 0 ]]; then
                echo -e "${GREEN}[INFORMATION] Playbook to run '$script_name_str' on haproxy executed successfully for: $p_hostname${NC}"
            else
                echo -e "${RED}[ERROR] Playbook to run '$script_name_str' on haproxy encountered an error for: $p_hostname${NC}"
                exit 1  # Exit the script with an error code
            fi
        
            # Wait for background process (ansible-playbook) to complete
            wait
        done

        # Check if are been added new haproxy
        # or configured only for new master nodes or first time
        if [ "$haproxy_to_add" -ge 1  ]
            # Updates json file moving 'ha_proxy_to_add' into 'ha_proxy_to_configure'
            hap_json_cluster_path_file="$i_json_path"
            hap_json_input=$(cat "$hap_json_cluster_path_file")

            # Migrate haproxy from 'haproxy_to_add' to 'haproxy_to_configure' and
            # set 'haproxy_to_add' to an empty array.
            hap_json_output=$(echo "$hap_json_input" | jq '.haproxy.haproxy_to_configure += .haproxy.haproxy_to_add | .haproxy.haproxy_to_add = []')

            # Check status
            hap_jq_status=$?

            # Check the exit status and take actions accordingly
            if [[ $hap_jq_status -eq 0 ]]; then
                echo -e "${GREEN}[INFORMATION] Json updated (haproxy)!${NC}"
            else
                echo -e "${RED}[ERROR] An exception occurred during the updates of the json (haproxy).${NC}"
                exit 1  # Exit the script with an error code
            fi

            # Save the updated JSON to a file
            echo "$hap_json_output" > "$hap_json_cluster_path_file"
        fi

        # print message
        echo "${GREEN}[INFORMATION] HAProxy configuration completed successfully!${NC}"
    else
        # Print message
        echo "[INFORMATION] HAProxy script is not enabled. Skipping configuration..."
    fi 
}



######################
#    START SCRIPT    #
######################

# Check if the filename is given
if [ "$#" -ne 1 ]; then
    echo -e "${RED}[ERROR] No arguments provided, see the example:${NC} ./scripts/k8s_cluster_creation/configure_cluster.sh cluster-dev.json"
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

# Read JSON data from the "nodes.json" file
json_data=$(cat "$NODES_JSON_PATH")

# haproxy variables
DNS_OR_IP=$(echo $json_data | jq -r 'haproxy.ssl.dns_or_ip') # For HAPROXY
KUBECONFIG_FIRST_TIME="false" # used to check the context and understand what execute (nodes)
HAPROXY_FIRST_TIME="false" # used to check the context and understand what execute (haproxy)
NEW_MASTER_NODES="false" # used to check if there are new master nodes to add (toadd ne masters on haproxy)
# Extracting values for haproxy from 'json_data'
haproxy_enabled=$(echo $json_data | jq -c '.haproxy.enabled')
ssl_enabled=$(echo $json_data | jq -r '.haproxy.ssl.enabled')
dns=$(echo $json_data | jq -r '.haproxy.ssl.dns')
password_shared_keepalived=$(echo $json_data | jq -r '.haproxy.haproxy_common_cfg.password')
vip=$(echo $json_data | jq -r '.haproxy.haproxy_common_cfg.vip')
haproxy_to_configure=$(echo $json_data | jq -c '.haproxy_to_configure[]')
haproxy_to_add=$(echo $json_data | jq -c '.haproxy_to_add[]')

# K8s nodes variables
nodes_to_add=$(echo $json_data | jq -c '.nodes_to_add[]')
nodes_to_configure=$(echo $json_data | jq -c '.nodes_to_configure[]')
nodes_to_configure_backup=$nodes_to_configure
nodes_to_add_backup=$nodes_to_add

# Print folders path
sudo echo "[INFORMATION] HOME user directory path: '$HOME_DIR'"
sudo echo "[INFORMATION] PWD user directory path: '$PWD_DIR'"


#####################
#  ADD NEW HAPROXY  #
#####################
haproxy_to_add=$(echo $json_data | jq -c 'haproxy.haproxy_to_add[]')
if [ -n "$haproxy_to_add" ]; then
    # Print message
    echo "[INFORMATION] Start to execute the procedure to add new haproxies..." 
    # Configure haproxy if enabled
    if [ "$haproxy_enabled" == "true" ]; then
        start_playbook_haproxy "$haproxy_enabled" "$nodes_to_add_backup" "$json_data" "$vip" "$ssl_enabled" "$dns" "$DNS_OR_IP" "$PWD_DIR" "$NODES_JSON_PATH"
    else
        echo -e "${RED}[ERROR] The cluster configurations, have not haproxy enabled. Please make sure that haprocy is enabled.${NC}"
        exit 1
    fi
    # Print message
    echo -e "${GREEN}[INFORMATION] New haproxies added, procedure executed successfully! ${NC}"
    exit 1 # Exit from script because you need only to add a new haproxy
fi


###############################################################
# CHECK IF IT IS A CLUSTER INSTALLATION OR ADDING A NEW NODES #
###############################################################

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
        echo -e "${GREEN}[INFORMATION] Json updated (new nodes)!${NC}"
    else
        echo -e "${RED}[ERROR] An exception occurred during the updates of the json (new nodes).${NC}"
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
#    CONFIGURING NODES OF THE CLUSTER   #
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
    master_type_node=$(echo $node | jq -r '.master_type')
    hostname=$(echo $node | jq -r '.hostname')
    echo ""
    echo "-----------------------------------"
    echo "        NODE TO CONFIGURE          "
    echo "-----------------------------------"
    echo "Node Type: $node_type"
    echo "SSH User Password: ***********"
    echo "Path Vars Ansible File: $path_vars_ansible_file"
    echo "Master Type: $master_type_node"
    echo "Hostname: $hostname"
    echo "-----------------------------------"
    echo ""
    
    # Need to understand the contexts:
    # - If it is first configuration of the cluster: 
    #   Here it is needed to install the k8s inside the master node.
    #   After that we need to check if haproxy is configured because if it is,
    #   we need to configure the haproxy and then, update the ip of the 
    #   .kubeconfig (if haproxy is enabled)
    # 
    # - If it is a new node to add to the cluster:
    #   In this case we have different scenario, because 
    #   haproxy is previously configured when the cluster k8s was created.
    #
    #   --> At the moment there isn't a mechanism to first create a cluster without haproxy and then 
    #   add haproxy to the cluster. So, if you create a cluster (without haproxy) you are able
    #   to upgrade the cluster adding new nodes, on the other hand you can't add haproxy (can you do it manually 
    #   but this means you need to change all the configurations of the nodes of the k8s cluster,
    #   because the ip adress of the API K8S, will be changed with the virtual ip of the haproxy).
    #   However, if you decide to create a cluster with at least one haproxy and then you want to add a
    #   new haproxy, you can do it. At the same time you can also upgrade the cluster adding new nodes. 
    #   Both scenarios support multi-master nodes. In the case to be withouth haproxy,
    #   the master control-plane, should be the first master node. Instead if you have configured haproxy, 
    #   the master control-plane it is the virtual ip address of the haproxy.

    # Checking the context...
    if [ "$NEW_NODE_OR_INIT" == "NEW_NODES" ]; then
        # New node to add to the cluster
        echo "[INFORMATION] New node to add to the cluster: $hostname"

        # Check if the are master nodes to add
        if [ "$node_type" == "master" ]; then
            NEW_MASTER_NODES="true"
        fi

        # Run the ansible playbook to configure the node
        start_playbook_nodes "$PWD_DIR/ansible/k8s_cluster_creation/inventory/hosts.yml" "$PWD_DIR/ansible/k8s_cluster_creation/playbooks/k8s_cluster_creation.yml" "@$PWD_DIR/$path_vars_ansible_file" "ansible_become_pass=$ssh_user_password"
    else
        if [ "$KUBECONFIG_FIRST_TIME" == "false" ]; then
            # First configuration of the cluster
            echo "[INFORMATION] First configuration of the cluster, start to configure the node: $hostname"
            
            # Check that the first node is a master
            # node and 'master_type' is set to 'master'
            # otherwise print an error...
            if [ "$node_type" != "master" ] && [ "$master_type_node" = "master" ]; then
                echo -e "${RED}[ERROR] The first node of the cluster must be a master node!${NC}"
                exit 1
            fi

            # Run the ansible playbook to configure the node
            start_playbook_nodes "$PWD_DIR/ansible/k8s_cluster_creation/inventory/hosts.yml" "$PWD_DIR/ansible/k8s_cluster_creation/playbooks/k8s_cluster_creation.yml" "@$PWD_DIR/$path_vars_ansible_file" "ansible_become_pass=$ssh_user_password"
            
            # We need to set a variable to true, because we need to update the kubeconfig
            # after the configuration of the haproxy (for the second node, before to
            # configure it, will be configured haproxy)
            KUBECONFIG_FIRST_TIME="true"
        else
            # At this stage, the script is configuring
            # the others nodes (backup master nodes or worker nodes)
            # So before to continue, we need to configure haproxy and then,
            # set a variabile to true. So the next cicle of the loop, all nodes
            # can join to the cluster using the updated 
            # .kubeconfig and api address, using the vip (virtual ip) or dns of the haproxy
            if [ "$HAPROXY_FIRST_TIME" == "false" ]; then
                ##############################################################
                #                 CHECK IF MANAGE HAPROXY                    #
                ##############################################################

                # Configure haproxy if enabled
                if [ "$haproxy_enabled" == "true" ]; then
                    start_playbook_haproxy "$haproxy_enabled" "$nodes_to_add_backup" "$json_data" "$vip" "$ssl_enabled" "$dns" "$DNS_OR_IP" "$PWD_DIR" "$NODES_JSON_PATH"
                fi

                # Update the variable for the others nodes
                HAPROXY_FIRST_TIME="true"
            else
                # Start playbook to configure the others nodes
                # using the vip (virtual ip) or dns of the haproxy (if set),
                # otherwise use master node ip address.
                start_playbook_nodes "$PWD_DIR/ansible/k8s_cluster_creation/inventory/hosts.yml" "$PWD_DIR/ansible/k8s_cluster_creation/playbooks/k8s_cluster_creation.yml" "@$PWD_DIR/$path_vars_ansible_file" "ansible_become_pass=$ssh_user_password"
            fi
        fi
    fi

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
echo "[INFORMATION] Starting to run the palybook to label the nodes..."
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


###################################################
# UPDATE HAPROXY IF A NEW MASTER NODES IS ADDED   #
###################################################

# Update haproxy if it has been added new master nodes
if [ "$haproxy_enabled" == "true" ] && [ "$NEW_NODE_OR_INIT" == "NEW_NODES" ]; then
    # Start the playbook to 
    # update the haproxy running the function
    start_playbook_haproxy "$haproxy_enabled" "$nodes_to_add_backup" "$json_data" "$vip" "$ssl_enabled" "$dns" "$DNS_OR_IP" "$PWD_DIR" "$NODES_JSON_PATH"
else 
    echo "[INFORMATION] HAProxy script is not enabled or the operation is not for new nodes (type of worker). Skipping updates haproxy..."
fi


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
