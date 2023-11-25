/* eslint-disable no-useless-escape */
import { FormDataModel, NodeConfigItemModel } from "../models/ClusterCreation/NodeConfigItemModel";
import ClusterConfigModel, { NodeConfig } from '../models/ClusterCreation/ClusterConfigModel';

interface ReturnYamlModel {
    file: string,
    filename: string,
}

class ClusterCreationBe {
    checkInputFields(nodeConfigList: NodeConfigItemModel[]) {
        try {
            
            // Validation: Check if there are at least two nodes and one master
            const masterNodes = nodeConfigList.filter((node) => node.NODE_TYPE === 'master');
            const workerNodes = nodeConfigList.filter((node) => node.NODE_TYPE === 'worker');

            if (masterNodes.length < 1 || workerNodes.length < 1) {
                return { success: false, message: 'Please provide at least one master and one worker node.' };
            }

            // Return a response if needed
            return { success: true, message: 'Data checked correctly!' };

        } catch (error: any) {
            return { success: false, message: `${error.message}. An error occurred in ui.src.be.ClusterCreation.checkInpiutFields during validation.` || 'An error occurred in ui.src.be.ClusterCreation.checkInpiutFields during validation.' };
        }            
    }

    createManifests(formData: FormDataModel, nodeConfigList: NodeConfigItemModel[]) {
        try {
            // Create a zip archive
            let arrYaml: ReturnYamlModel[] = [];

            // Create a JSON string for the json_hostnames field
            const jsonHostnames = {
                hostnames: nodeConfigList.map((node) => ({
                    hostname: node.HOSTNAME,
                    ip: node.NODE_IP,
                })),
            };

            // Save json into string
            const jsonHostnamesString = JSON.stringify(jsonHostnames).replace(/"/g, '\\\\\\\"');

            // Iterate over each node in the node configuration list
            nodeConfigList.forEach((nodeConfig, index) => {
                // Create the YAML content based on the template
                const yamlContent = `##########################
# node variables         #
##########################
ansible_host: "${nodeConfig.ANSIBLE_HOST}"
node_name: "${nodeConfig.HOSTNAME}"
node_ssh_user: "${nodeConfig.SSH_USER}"
ssh_private_key_path: "${nodeConfig.SSH_KEY_PATH}"
ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
storj_secret: "${formData.STORJ_SECRET}"
storj_bucket: "${formData.STORJ_BUCKET}"
cluster_name: "${formData.CLUSTER_NAME}"

##########################
# tools variables        #
##########################
# init_node.sh
k8s_version: "${formData.K8S_V}"
cri_version: "${formData.CRI_V}"
cri_os: "${formData.CRI_OS}"
required_ports: "${nodeConfig.REQ_PORTS}"
open_ports_for_master_or_worker: "${nodeConfig.OPEN_PORTS}"
json_hostnames: "${jsonHostnamesString}"

# To add a new nodes
new_json_hostnames: ""

# setup_node.sh
node_type: "${nodeConfig.NODE_TYPE}"
node_ip: "${nodeConfig.NODE_IP}"
pod_cidr: "${formData.POD_CIDR}"

##########################
# system variables       #
##########################
env: "${formData.ENV}"
local_path_git: "${formData.PROJECT_GIT_PATH}"
                `;

                // Specify the path where you want to save the YAML file
                const filePath = `${formData.PROJECT_GIT_PATH}` + `/ansible/k8s_cluster_creation/inventory/group_vars/${formData.CLUSTER_NAME}/${nodeConfig.HOSTNAME}.yml`.replace(/-/g, '_');
                
                // Push to array
                arrYaml.push({ file: `${yamlContent}`, filename: `${nodeConfig.HOSTNAME}`.replace(/-/g, '_') });

                // Log the file creation
                console.log(`YAML file created for ${nodeConfig.HOSTNAME}: ${filePath}`);
            });

            // Return a response if needed
            return { success: true, message: 'YAML files created!', result: arrYaml };
        } catch (error: any) {
            return { success: false, message: `${error.message}. An error occurred in ui.src.be.ClusterCreation.createManifests during the creation of the manifests.` || 'An error occurred in ui.src.be.ClusterCreation.createManifests during the creation of the manifests.', result: [] };
        }  
    }

    createJson(formData: FormDataModel, nodeConfigList: NodeConfigItemModel[]) { 
        try {   
            // Declare variables
            let hostnameMasterFile = "";
            let sshUserPasswordMaster = "";
            const nodesDataList: NodeConfig[] = [];

            // Loop through nodeConfigList to populate workerNodeDataList
            for (let index = 0; index < nodeConfigList.length; index++) {
                // Save single node
                const node = nodeConfigList[index];
                
                // Check if master..
                // if master save same fields for later
                if (node.NODE_TYPE === "master") {
                    hostnameMasterFile = `${node.HOSTNAME}`;
                    sshUserPasswordMaster = `${node.SSH_PASSWORD}`;
                }
                
                // Add node
                const nodeData: NodeConfig = {
                    node_type: `${node.NODE_TYPE}`,
                    ssh_user_password: `${node.SSH_PASSWORD}`,
                    path_vars_ansible_file: `ansible/k8s_cluster_creation/inventory/group_vars/${formData.CLUSTER_NAME}/${node.HOSTNAME}.yml`.replace(/-/g, '_'),
                    hostname: `${node.HOSTNAME}`,
                    ip: `${node.NODE_IP}`,
                    physical_env: `${node.PHYSICAL_ENV}`,
                    ssh_username: `${node.SSH_USER}`,
                    ssh_key_path: `${node.SSH_KEY_PATH}`,
                    net_ports_conf: `${node.REQ_PORTS}`,
                    ports_open_method: `${node.OPEN_PORTS}`,
                    ansible_host: `${node.ANSIBLE_HOST}`,
                };
                nodesDataList.push(nodeData);
            }

            // Create an instance of ClusterConfigModel
            const clusterConfigInstance = new ClusterConfigModel({
            path_vars_file_master_node_ansible: `ansible/k8s_cluster_creation/inventory/group_vars/${formData.CLUSTER_NAME}/${hostnameMasterFile}.yml`.replace(/-/g, '_'),
            ssh_user_password_master_node: sshUserPasswordMaster,
            cluster_name: formData.CLUSTER_NAME,
            storj_bucket_name: formData.STORJ_BUCKET,
            storj_export: formData.STORJ_SECRET,
            kubeconfig_setup: "true",
            nodes_to_configure: nodesDataList,
            pod_cidr: formData.POD_CIDR,
            k8s_version: formData.K8S_V,
            cri_version: formData.CRI_V,
            cri_os: formData.CRI_OS,
            ports_env: formData.ENV,
            project_git_path: formData.PROJECT_GIT_PATH,
            nodes_to_add: [],
            });
        
            // Return message
            return { success: true, message: 'Json created!', result:  clusterConfigInstance.toString() };

        } catch (error: any) {
            return { success: false, message: `${error.message}. An error occurred in ui.src.be.ClusterCreation.createJson during the creation of the json.` || 'An error occurred in ui.src.be.ClusterCreation.createJson during the creation of the json.', result: "" };
        }  
    }
}

export default ClusterCreationBe;
