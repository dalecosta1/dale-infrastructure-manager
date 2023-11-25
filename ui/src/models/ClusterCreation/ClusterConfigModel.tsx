export interface NodeConfig {
    node_type: string;
    ssh_user_password: string;
    path_vars_ansible_file: string;
    hostname: string;
    ip: string;
    physical_env: string;
    ssh_username: string,
    ssh_key_path: string,
    net_ports_conf: string,
    ports_open_method: string,
    ansible_host: string;
}
  
interface ClusterConfig {
    path_vars_file_master_node_ansible: string;
    ssh_user_password_master_node: string;
    cluster_name: string;
    storj_bucket_name: string;
    storj_export: string;
    kubeconfig_setup: string;
    pod_cidr: string;
    k8s_version: string;
    cri_version: string;
    cri_os: string;
    ports_env: string;
    project_git_path: string;
    nodes_to_configure: NodeConfig[];
    nodes_to_add: NodeConfig[];
}
  
class ClusterConfigModel implements ClusterConfig {
    path_vars_file_master_node_ansible: string = '';
    ssh_user_password_master_node: string = '';
    cluster_name: string = '';
    storj_bucket_name: string = '';
    storj_export: string = '';
    kubeconfig_setup: string = '';
    pod_cidr: string = '';
    k8s_version: string = '';
    cri_version: string = '';
    cri_os: string = '';
    ports_env: string = '';
    project_git_path: string = '';
    nodes_to_configure: NodeConfig[] = [];
    nodes_to_add: NodeConfig[] = [];

    constructor(data: Partial<ClusterConfigModel> = {}) {
        Object.assign(this, data);
    }

    toString(): string {
        return JSON.stringify(this, null, 2);
    }
}
  
export default ClusterConfigModel;
