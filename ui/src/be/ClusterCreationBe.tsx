/* eslint-disable no-unreachable */
/* eslint-disable no-useless-escape */
import { FormDataModel, HAProxy, HAProxyCommon, NodeConfigItemModel } from "../models/ClusterCreation/NodeConfigItemModel";
import ClusterConfigModel, { HAProxyConfig, NodeConfig } from '../models/ClusterCreation/ClusterConfigModel';

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

    createManifests(formData: FormDataModel, nodeConfigList: NodeConfigItemModel[], haProxy: HAProxyConfig) {
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

##########################
# haproxy                #
##########################
haproxy_enabled: "${haProxy.enabled}"
haproxy_port: "${haProxy.ssl.port}"
haproxy_dns_or_ip: "${haProxy.ssl.dns_or_ip}"
haproxy_ip: "${haProxy.haproxy_common_cfg.vip}"
haproxy_dns: "${haProxy.ssl.dns}"
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

    createHAProxyConfig(haproxyCommon: HAProxyCommon, haproxyConfigList: HAProxy[]) {
        let haproxy: HAProxyConfig = {
            enabled: '',
            ssl: {
                enabled: '',
                dns: '',
                dns_or_ip: '',
                port: '',
            },
            haproxy_common_cfg: {
                password: '',
                vip: '',
            },
            haproxy_to_configure: [],
            haproxy_to_add: [],
        };
        try {
            // Check that haproxy is enabled
            if (haproxyConfigList.length > 0) {
                haproxy.enabled = 'true';

                // Check that the password is not empty
                if (haproxyCommon.password.length === 0) {
                    return { success: false, message: 'Please provide a password for the HAProxy configuration.', result: haproxy };
                } else {
                    // Set password
                    haproxy.haproxy_common_cfg.password = haproxyCommon.password;
                }
                
                // Check that the vip is not empty
                if (haproxyCommon.vip.length === 0) {
                    return { success: false, message: 'Please provide a vip for the HAProxy configuration.', result: haproxy };
                } else {
                    // Set vip
                    haproxy.haproxy_common_cfg.vip = haproxyCommon.vip;
                }
                
                // Loop through haproxyConfigList to populate haproxy_to_configure
                for (let index = 0; index < haproxyConfigList.length; index++) {
                    // Save single haproxy
                    const haproxyConfig = haproxyConfigList[index];
                    // Add haproxy
                    const haproxyData = {
                        ip: `${haproxyConfig.ip}`,
                        lan_interface: `${haproxyConfig.lan_interface}`,
                        state: `${haproxyConfig.state}`,
                        hostname: `${haproxyConfig.hostname}`,
                        router_id: `${haproxyConfig.router_id}`,
                        priority: `${haproxyConfig.priority}`,
                        ssh_endpoint: `${haproxyConfig.ssh_endpoint}`,
                        ssh_username: `${haproxyConfig.ssh_username}`,
                        ssh_password: `${haproxyConfig.ssh_password}`,
                        ssh_key_path: `${haproxyConfig.ssh_key_path}`,
                        physical_env: `${haproxyConfig.physical_env}`,
                        internal_or_external: `${haproxyConfig.internal_or_external}`,
                    };
                    haproxy.haproxy_to_configure.push(haproxyData);
                }
                haproxyCommon.sslEnabled = true;
            } else {
                // Haproxy is not enabled
                haproxy.enabled = 'false';
                haproxy.haproxy_common_cfg.password = '';
                haproxy.haproxy_common_cfg.vip = '';
                haproxyCommon.sslEnabled = false;
            }

            // Check that ssl is enabled
            if (haproxyCommon.sslEnabled) {
                haproxy.ssl.enabled = 'true';
                // Check that the domain is not empty
                if (haproxyCommon.domain.length === 0) {
                    return { success: false, message: 'Please provide a domain name for the HAProxy configuration.', result: haproxy };
                } else {
                    // Set dns
                    haproxy.ssl.dns = haproxyCommon.domain;
                    haproxy.ssl.dns_or_ip = 'dns';
                    haproxy.ssl.port = '443';
                }
            } else {
                // Ssl is not enabled
                haproxy.ssl.enabled = 'false';
                haproxy.ssl.dns = '';
                haproxy.ssl.dns_or_ip = 'ip';
                haproxy.ssl.port = '6443';
            }

            // Return a response
            return { success: true, message: 'HAProxy configured!', result: haproxy };
        } catch (error: any) {
            return { success: false, message: `${error.message}. An error occurred in ui.src.be.ClusterCreation.createHAProxyConfig during the configuration of the proxies.` || 'An error occurred in ui.src.be.ClusterCreation.createHAProxyConfig during the configuration of the proxies.', result: haproxy };
        }  
    }

    createJson(formData: FormDataModel, nodeConfigList: NodeConfigItemModel[], haProxy: HAProxyConfig) { 
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
                    master_type: `${node.MASTER_TYPE}`,
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
            haproxy: haProxy,
            });
        
            // Return message
            return { success: true, message: 'Json created!', result: clusterConfigInstance.toString() };

        } catch (error: any) {
            return { success: false, message: `${error.message}. An error occurred in ui.src.be.ClusterCreation.createJson during the creation of the json.` || 'An error occurred in ui.src.be.ClusterCreation.createJson during the creation of the json.', result: "" };
        }  
    }
}

export default ClusterCreationBe;
