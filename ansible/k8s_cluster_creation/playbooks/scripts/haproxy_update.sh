#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# //////////////////////////////////////////////////////////
#                     HAProxy Updates                      /
# //////////////////////////////////////////////////////////

# EXAMPLE OF INPUT STRING ARGUMENT
# {
#     "ssl": {
#         "enabled": true,
#         "dns_or_ip": "dns",
#         "dns": "k8s-cluster-dev.mydomain.com"     
#     },
#     "haproxy": {
#         "hostname": "haproxy-2-1",
#         "lan_interface": "eth0",
#         "ip": "192.168.3.14",
#         "state": "MASTER",
#         "router_id": "104",
#         "priority": "100",
#         "password": ",clwioji34hui3hiu3hiu",
#         "vip":"192.168.3.50"
#     },
#     "master_nodes": [
#         {
#             "hostname": "k8s-master-node-1-1-srv1",
#             "ip": "192.168.3.11"
#         },
#         {
#             "hostname": "k8s-master-node-2-1-srv1",
#             "ip": "192.168.3.12"
#         }
#     ]
# }

# Check for the argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 '<json_string>'"
    exit 1
fi

# Read the argument into a variable
json_input=$1

# Extract master nodes from JSON input
master_nodes=$(echo "$json_input" | jq -c '.master_nodes[]')

# Define the path of HAProxy configuration file
HAPROXY_CFG_PATH="/etc/haproxy/haproxy.cfg"

# Create a backup of the original configuration
sudo cp "$HAPROXY_CFG_PATH" "${HAPROXY_CFG_PATH}.backup"

# Temporary file for updated configuration
TEMP_CFG_FILE=$(mktemp)

# Copy the existing configuration up to the end of the master nodes list
sed '/# === END MASTER NODES ===/q' $HAPROXY_CFG_PATH > $TEMP_CFG_FILE

# Append new nodes configuration
while read -r node; do
    node_hostname=$(echo "$node" | jq -r '.hostname')
    node_ip=$(echo "$node" | jq -r '.ip')
    echo "    server $node_hostname $node_ip:6443 check fall 3 rise 2" >> "$TEMP_CFG_FILE"
done <<< "$master_nodes"

# Append the rest of the original configuration file
sed -n '/# === END MASTER NODES ===/,$p' $HAPROXY_CFG_PATH >> $TEMP_CFG_FILE

# Move the updated configuration back to the original file
sudo mv $TEMP_CFG_FILE $HAPROXY_CFG_PATH

# Restart HAProxy to apply changes
sudo systemctl restart haproxy

# Print completion message
echo "[INFORMATION] HAProxy master nodes updated and service restarted successfully!"

# Remove file
sudo rm -rf "${HAPROXY_CFG_PATH}.backup"
