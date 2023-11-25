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
