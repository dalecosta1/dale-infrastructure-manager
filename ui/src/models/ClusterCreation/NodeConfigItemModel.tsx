// NodeConfigItem
interface NodeConfigItem {
  ANSIBLE_HOST: string;
  HOSTNAME: string;
  SSH_USER: string;
  SSH_PASSWORD: string;
  SSH_KEY_PATH: string;
  REQ_PORTS: string;
  OPEN_PORTS: string;
  NODE_TYPE: string;
  NODE_IP: string;
  PHYSICAL_ENV: string;
  MASTER_TYPE: string;
}
  
export class NodeConfigItemModel implements NodeConfigItem {
  ANSIBLE_HOST: string = '';
  HOSTNAME: string = '';
  SSH_USER: string = '';
  SSH_PASSWORD: string = '';
  SSH_KEY_PATH: string = '';
  REQ_PORTS: string = '';
  OPEN_PORTS: string = '';
  NODE_TYPE: string = '';
  NODE_IP: string = '';
  PHYSICAL_ENV: string = '';
  MASTER_TYPE: string = '';

  constructor(data: Partial<NodeConfigItemModel> = {}) {
    Object.assign(this, data);
  }
}

// FormData
interface FormData {
  STORJ_SECRET: string;
  STORJ_BUCKET: string;
  CLUSTER_NAME: string;
  JSON_HOSTNAMES: string;
  POD_CIDR: string;
  K8S_V: string;
  CRI_V: string;
  CRI_OS: string;
  ENV: string;
  PROJECT_GIT_PATH: string;
}

export class FormDataModel implements FormData {
  STORJ_SECRET: string = '';
  STORJ_BUCKET: string = '';
  CLUSTER_NAME: string = '';
  JSON_HOSTNAMES: string = '';
  POD_CIDR: string  = '';
  K8S_V: string = '';
  CRI_V: string = '';
  CRI_OS: string = '';
  ENV: string = '';
  PROJECT_GIT_PATH: string = '';

  constructor(data: Partial<NodeConfigItemModel> = {}) {
    Object.assign(this, data);
  }
}

interface HAProxyCommonModel {
  password: string;
  vip: string;
  sslEnabled: boolean;
  domain: string;
}

export class HAProxyCommon implements HAProxyCommonModel {
  password: string = '';
  vip: string = '';
  sslEnabled: boolean = false;
  domain: string = '';

  constructor(data: Partial<HAProxyCommonModel> = {}) {
    Object.assign(this, data);
  }
}

interface HAProxyModel {
  ip: string;
  lan_interface: string;
  state: string;
  hostname: string;
  router_id: string;
  priority: string;
  ssh_endpoint: string;
  ssh_username: string;
  ssh_password: string;
  ssh_key_path: string;
  physical_env: string;
  internal_or_external: string;
}

export class HAProxy implements HAProxyModel {
  ip: string = '';
  lan_interface: string = '';
  state: string = '';
  hostname: string = '';
  router_id: string = '';
  priority: string = '';
  ssh_endpoint: string = '';
  ssh_username: string = '';
  ssh_password: string = '';
  ssh_key_path: string = '';
  physical_env: string = '';
  internal_or_external: string = '';

  constructor(data: Partial<HAProxyModel> = {}) {
    Object.assign(this, data);
  }
}