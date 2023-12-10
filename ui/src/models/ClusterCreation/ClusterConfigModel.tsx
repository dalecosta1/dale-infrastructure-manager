
/* HAProxy configuration */
export interface SslConfig {
    enabled: string;
    dns: string;
}

export interface HAProxyCommonConfig {
    password: string;
    vip: string;
}

export interface HAProxyNodeConfig {
    hostname: string;
    lan_interface: string;
    ip: string;
    state: string;
    router_id: string;
    priority: string;
    ssh_endpoint: string;
    ssh_username: string;
    ssh_password: string;
    ssh_key_path: string;
}

export interface HAProxyConfig {
    enabled: string;
    ssl: SslConfig;
    haproxy_common_cfg: HAProxyCommonConfig;
    haproxy_to_configure: HAProxyNodeConfig[];
    haproxy_to_add: HAProxyNodeConfig[];
}

/* Nodes configuration */
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
    master_type: string,
    ansible_host: string;
}

/* Cluster configuration */
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
    haproxy: HAProxyConfig;
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
    haproxy: HAProxyConfig = {
        enabled: '',
        ssl: {
            enabled: '',
            dns: ''
        },
        haproxy_common_cfg: {
            password: '',
            vip: ''
        },
        haproxy_to_configure: [],
        haproxy_to_add: []
    };

    constructor(data: Partial<ClusterConfigModel> = {}) {
        Object.assign(this, data);
    }

    toString(): string {
        return JSON.stringify(this, null, 2);
    }
}
  
export default ClusterConfigModel;
