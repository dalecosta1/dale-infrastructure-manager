
# 👨‍💻 DALE-INFRASTRUCTURE-MANAGER

In-house k8s cluster creation using the dale-infrastructure-manager which is a versatile tool leverages Ansible for automation. With the UI you can generate the manifests and the json to run the ansible playbooks via bash script, creating a k8s cluster with kubeadm. There is also the possibility to add new nodes on cluster. The configuration of the k8s cluster is valid for an on-prem scenario and also for cloud providers such as azure, aws, google, digital ocean, etc...


## 🪅 Compatibility

This project can be executed on the following platforms:

- Windows 11 (using Ubuntu via WSL)
- From macOS Monterey 12.4 (arm & amd)
- Ubuntu 22.04

Cluster node OS availables:

- Ubuntu Server 22.04


## ☁️ Cloud providers integration (azure, aws, digital ocean, etc...)

It is possible configures a k8s cluster also with vms running on cloud providers such as azure, aws, digital ocean, google, etc...
To integrate dale-infrastructure-manger with vms on cloud, there are two possible scenarios:

- Vms on VPC (Virtual Private Cloud): In this case th ip provided on UI or added manually on json and manifests can be the private ip of the VPC where virtual machines run. In this case if it is not possible reach the vms on public internet, it is possible run this project on a local vm inside the VPC using the internal ip of the vms (inside the VPC). Keep in mind that all vms have to connect on internet to configure the packages repositories. 

- Public vms: If you istance 'N' public vms or you create a VPC reachable by the external network, it is possible use the public ip of every single vm.

If you work inside the network (on-prem), you can use the internal nodes ip of the cluster (eg: 192.168.1.214, 192.168.1.101).
The dale-infrastructure-manager works well for both cases on-prem & cloud 🛸🛸


## 🤹‍♂️ Tech Stack

**UI:** react-ts

**BE:** ansible, bash, YAML & json


## 🎰 Installation

Check if there are the folder '.kube' on home user profile directory. If there isn't, create it:

```bash
  cd $HOME
  mkdir .kube
```

Check the folder 'config' inside '.kube'. If there isn't, create it:

```bash
  cd $HOME
  mkdir .kube/config
```

Now go inside the folder where you want clone the project
(advice: clone the repo on folders such as 'workspace' or 'source' under user profile):

```bash
  git clone https://github.com/dalecosta1/dale-infrastructure-manager.git
  cd dale-infrastructure-manager
```

When inside the repo, we need to make executable the 'setup.sh':

```bash
  sudo chmod +x setup.sh
```

Now it is possible start the setup:

```bash
  ./setup.sh
```

After the execution of the setup, is possible start the UI 
to get the manifests to start the creation of the k8s cluster.


## 🪣 Storj bucket configuration

We need to configure and signin on storj to automate the process of the cluster creation when the worker nodes read from storj the '.kubeconfig' file to join to the master node and to the cluster (storj uplink CLI is installed during the execution of the 'setup.sh').
For this reason you need to signin here https://eu1.storj.io/login (EU) or https://us1.storj.io/login (US), create an account and save all the secret keys required.
See storj: https://www.storj.io/.
See docs uplink cli: https://docs.storj.io/dcs/api/uplink-cli.

Required keys to save:

- Satellite address
- Api key
- Passphase

Once you have registered, you need to create an api key to access to the bucket. After that,
is possible generate the export to put on the manifests or UI. To generate the export just only open
your terminal executing this:

```bash
uplink setup
#Enter name to import as [default: main]: main
#Enter API key or Access grant: 122kfj3hfh3u5hh3hu3h53h32smu53h35h3u35hu5353u5h3u35uhhu35uh3huduwheuhuwgywegdetdt
#Satellite address: 122kfj3hfh3u5hh3hu3h53h32smu53h35h3u@eu1.storj.io:7777
#Passphrase: 
#Again: 
#Would you like to disable encryption for object keys (allows lexicographical sorting of objects in listings)? (y/N): n
#Imported access "main" to "/home/user1/.config/storj/uplink/access.json"
#Switched default access to "main"
#Would you like S3 backwards-compatible Gateway credentials? (y/N): n
```

After the initialization of the storj bucket do the export to insert inside the json and manifests or on UI:

```bash
uplink access export main export_storj.txt
```

Inside the file .txt will be the export.


## 🖥 UI

To generate the manifests and the YAML files, to run the bash script, is possible start the ui to get the files required. To start the UI enter on ui folder:

```bash
  cd ui
```

If not installed, install npm packages (operation done during the 'setup.sh' execution):

```bash
  sudo npm i
  sudo npm i --save-dev @types/file-saver
```

Start UI:

```bash
  sudo npm run start
```

Compile the for 'Cluster creation' to generate the manifests.


## 🚀 BE - Create new cluster

Before to start, understand that ansible work with underscore, so all files inside the folders 'ansible' and 'scripts' are with underscore. Use this nomenclature please. Once you got the manifests, put the YAML inside inside a new folder under ansible/k8s_cluster_creation/inventory/group_vars. The folder it is preferible that it is called as the name of the cluster eg: cluster_dev --> So put YAML into ansible/k8s_cluster_creation/inventory/group_vars/cluster_dev.

Make sure 'start_ansible.sh' is executable (done by the script setup.sh):

- MacOS:
```bash
  cd dale-infrastructure-manager
  sudo chmod +x scripts/k8s_cluster_creation/start_ansible.sh
```

After this, put the json file inside the folder scripts/k8s_cluster_creation/json.
Create the folder json and add the json file downlaoded from UI, eg: scripts/k8s_cluster_creation/json/cluster_dev.json
Now, go on root folder of the git project:

- MacOS:
```bash
  sudo -s
  cd dale-infrastructure-manager
  # Start the bash script... eg: ./scripts/k8s_cluster_creation/start_ansible.sh cluster_dev.json
  ./scripts/k8s_cluster_creation/start_ansible.sh <json_file_name>
```

- Ubuntu:
```bash
  cd dale-infrastructure-manager
  # Start the bash script... eg: ./scripts/k8s_cluster_creation/start_ansible.sh cluster_dev.json
  ./scripts/k8s_cluster_creation/start_ansible.sh <json_file_name>
```

Start the script 'start_ansible.sh' passing by arg. the name of the file json with the nodes configurations to create the cluster. The script will start the execution of the procedure. 

At the end the procedure if doing 'kubectl get nodes' you get error:

```bash
#W1125 23:56:55.773104   29968 loader.go:221] Config not found: /Users/user1/.kube/config/devops/kubeconfig
#The connection to the server localhost:8080 was refused - did you specify the right host or port?
#OR
#error: error loading config file "/Users/user1/.kube/config": read /Users/user1/.kube/config: is a directory
```

You need to do the export PATH manually. To do it,
is necessary copy and past the command suggested by the script 'start_ansible.sh' at the end of the script:

```bash
#[INFORMATION] If 'kubectl get nodes' does not return the number of nodes on the cluster, maybe you need to run 'export KUBECONFIG' manually. Open the terminal and copy-past this: 'export KUBECONFIG="/Users/user1/.kube/config/cluster-dev/kubeconfig"'
#[INFORMATION] Kubeconfig configured correctly on the local machine: /Users/user1/.kube/config/cluster-dev/kubeconfig
```

Now, after you copy the suggested export, on terminal try again 'kubectl get nodes':

```bash
export KUBECONFIG="/Users/user1/.kube/config/cluster-dev/kubeconfig"
kubectl get nodes                                                                                       
#NAME                  STATUS   ROLES                  AGE     VERSION
#k8s-master-node-1-1   Ready    control-plane,master   20m     v1.28.4
#k8s-worker-node-1-2   Ready    worker                 2m38s   v1.28.4
```

## 🚀 BE - Add new nodes

If you need to add new nodes to the cluster, just add a
new entity in the array of the json 'add_new_nodes':

```json
  {
    ...others properties...
    "nodes_to_add": [
      {
        "node_type": "worker",
        "ssh_user_password": "password_user",
        "path_vars_ansible_file": "ansible/k8s_cluster_creation/inventory/group_vars/cluster_dev/k8s_worker_node_1_5_srv1.yml",
        "hostname": "k8s-worker-node-1-4-srv1",
        "ip": "ip_address",
        "physical_env": "srv1",
        "ssh_username": "ssh_username",
        "ssh_key_path": "path_where_is_stored_ssh_key",
        "net_ports_conf": "true",
        "ports_open_method": "worker",
        "ansible_host": "k8s-worker-node-1-4-srv1.com"
      },
      {
        "node_type": "worker",
        "ssh_user_password": "password_user",
        "path_vars_ansible_file": "ansible/k8s_cluster_creation/inventory/group_vars/cluster_dev/k8s_worker_node_1_5_srv1.yml",
        "hostname": "k8s-worker-node-1-5-srv1",
        "ip": "ip_address",
        "physical_env": "srv1",
        "ssh_username": "ssh_username",
        "ssh_key_path": "path_where_is_stored_ssh_key",
        "net_ports_conf": "true",
        "ports_open_method": "worker",
        "ansible_host": "k8s-worker-node-1-5-srv1.com"
      }  
    ] 
  }
```

Now is possible run again the script:

- MacOS:
```bash
  sudo -s
  cd dale-infrastructure-manager
  # Start the bash script... eg: ./scripts/k8s_cluster_creation/start_ansible.sh cluster_dev.json
  ./scripts/k8s_cluster_creation/start_ansible.sh <json_file_name>
```

- Ubuntu:
```bash
  cd dale-infrastructure-manager
  # Start the bash script... eg: ./scripts/k8s_cluster_creation/start_ansible.sh cluster_dev.json
  ./scripts/k8s_cluster_creation/start_ansible.sh <json_file_name>
```

## 📜 Template YAML

```yaml
  ##########################
  # node variables         #
  ##########################
  ansible_host: "$ANSIBLE_HOST" # Host where we want connect eg. k8s-master-node-1-1-srv1.com
  node_name: "$HOSTNAME" # Hostname eg. k8s-master-node-1-1-srv1
  node_ssh_user: "$SSH_USER" # Vm username eg. masternode11
  ssh_private_key_path: "$SSH_KEY_PATH" # Path ssh key eg. /home/user1/.ssh/id_rsa
  ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
  storj_secret: "$STORJ_SECRET" # Storj secret eg. dadhr42ruifuhwefuyhf2378f23f238f89f89fu89f
  storj_bucket: "$STORJ_BUCKET" # Storj bucket name eg. dale-infrastructure-manager
  cluster_name: "$CLUSTER_NAME" # Cluster name eg. cluster-dev

  ##########################
  # tools variables        #
  ##########################
  # init_node.sh
  k8s_version: "$K8S_V" # K8s version eg. 1.28.4-1.1
  cri_version: "$CRI_V" # Cri version eg. 1.28
  cri_os: "$CRI_OS" # Os selected for the cri eg. xUbuntu_22.04
  required_ports: "$REQ_PORTS" # true or false: true open the ports false not open the ports
  open_ports_for_master_or_worker: "$OPEN_PORTS" # [master]: open ports for master, [worker]: open ports for worker, [both]: open the ports of the master node and worker, [all]: open all ports
  json_hostnames: "$JSON_HOSTNAMES" # Hostnames to add in /etc/hosts

  # To add a new nodes
  new_json_hostnames: "" # This variable is auto-populated by the scripts, used to add new nodes

  # setup_node.sh
  node_type: "$NODE_TYPE" # [master]: to configure the node as masternode, [worker]: to configure the node as workernode
  node_ip: "$NODE_IP" # Ip address of the node (for remote vms on cloud provider use the public ip instead of the private) eg. 192.168.3.45 for private ip or 3.211.4.7 for public ip 
  pod_cidr: "$POD_CIDR" # Subnetmask of the pod cidr eg. 10.244.0.0/16

  ##########################
  # system variables       #
  ##########################
  env: "$ENV" # [prod] open only required pods 443 and 6443, [dev] open also 5001, 80, 8080 for dev env.
  local_path_git: "$PROJECT_GIT_PATH" # Path of the repo eg. /home/user1/workspace/dale-infrastructure-manager
```


## 📜 Template json

```json
  {
    "path_vars_file_master_node_ansible": "ansible/k8s_cluster_creation/inventory/group_vars/cluster_dev/k8s_master_node_1_1_srv1.yml",
    "ssh_user_password_master_node": "password",
    "cluster_name": "cluster-dev",
    "storj_bucket_name": "dale-infrastructure-manager",
    "storj_export": "STORJ_EXPORT",
    "kubeconfig_setup": "true",
    "pod_cidr": "10.244.0.0/16",
    "k8s_version": "1.28.4-1.1", 
    "cri_version": "1.28",
    "cri_os": "xUbuntu_22.04",
    "ports_env": "prod",
    "project_git_path": "/home/user1/workspace/dale-infrastructure-manager",
    "nodes_to_configure": [
      {
        "ansible_host": "k8s-master-node-1-1-srv1.com",
        "node_type": "master",
        "ssh_username": "ssh_username",
        "ssh_key_path": "path_where_is_stored_ssh_key",
        "net_ports_conf": "true",
        "ports_open_method": "master",
        "ssh_user_password": "password_user",
        "path_vars_ansible_file": "ansible/k8s_cluster_creation/inventory/group_vars/cluster_dev/k8s_master_node_1_1_srv1.yml",
        "hostname": "k8s-master-node-1-1-srv1",
        "ip": "ip_address",
        "physical_env": "srv1"
      },
      {
        "node_type": "worker",
        "ssh_user_password": "password_user",
        "path_vars_ansible_file": "ansible/k8s_cluster_creation/inventory/group_vars/cluster_dev/k8s_worker_node_1_2_srv1.yml",
        "hostname": "k8s-worker-node-1-2-srv1",
        "ip": "ip_address",
        "physical_env": "srv1",
        "ssh_username": "ssh_username",
        "ssh_key_path": "path_where_is_stored_ssh_key",
        "net_ports_conf": "true",
        "ports_open_method": "worker",
        "ansible_host": "k8s-worker-node-1-2-srv1.com"
      },
      {
        "node_type": "worker",
        "ssh_user_password": "password_user",
        "path_vars_ansible_file": "ansible/k8s_cluster_creation/inventory/group_vars/cluster_dev/k8s_worker_node_1_3_srv1.yml",
        "hostname": "k8s-worker-node-1-3-srv1",
        "ip": "ip_address",
        "physical_env": "srv1",
        "ssh_username": "ssh_username",
        "ssh_key_path": "path_where_is_stored_ssh_key",
        "net_ports_conf": "true",
        "ports_open_method": "worker",
        "ansible_host": "k8s-worker-node-1-3-srv1.com"
      }
    ],
    "nodes_to_add": []
  }
```
