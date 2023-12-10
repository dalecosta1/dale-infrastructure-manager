import React, { useState } from 'react';
import Visibility from '@mui/icons-material/Visibility';
import VisibilityOff from '@mui/icons-material/VisibilityOff';
import { ToastContainer, toast } from 'react-toastify';
import 'react-toastify/dist/ReactToastify.css';
import JSZip from 'jszip';
import { saveAs } from 'file-saver';
import { NodeConfigItemModel, HAProxy } from '../models/ClusterCreation/NodeConfigItemModel';
import ClusterCreationBe from '../be/ClusterCreationBe';
import {
  TextField,
  Button,
  Typography,
  Container,
  MenuItem,
  Select,
  InputLabel,
  FormControl,
  SelectChangeEvent,
  Box,
  InputAdornment,
  IconButton,
  FormControlLabel,
  Checkbox
} from '@mui/material';

const ClusterCreation: React.FC = () => {
  // Shared configurations
  const [formData, setFormData] = useState({
    STORJ_SECRET: '',
    STORJ_BUCKET: '',
    CLUSTER_NAME: '',
    JSON_HOSTNAMES: '',
    POD_CIDR: '',
    K8S_V: '',
    CRI_V: '',
    CRI_OS: '',
    ENV: '',
    PROJECT_GIT_PATH: '',
  });

  const handleChange = (name: string) => (event: React.ChangeEvent<HTMLInputElement>) => {
    setFormData({ ...formData, [name]: event.target.value });
  };

  const handleSelectChange = (name: string) => (
    event: SelectChangeEvent<string>
  ) => {
    setFormData({ ...formData, [name]: event.target.value });
  };

  const handleSubmit = () => {
    // Create an instance of the backend class
    const clusterCreationBe = new ClusterCreationBe();
    const zip = JSZip();

    // You can perform validation here before submitting 
    const checkInputFieldsResult = clusterCreationBe.checkInputFields(nodeConfigList);
    if (!checkInputFieldsResult.success) {
      // Show an error notification
      toast.error(checkInputFieldsResult.message);
      return;
    }

    // Set CRI_V based on K8S_V selected
    switch (formData.K8S_V) {
      case '1.28.2-00':
      case '1.28.4-1.1':
        formData.CRI_V = '1.28';
        break;
    } 

    // Check
    if(formData.CRI_V === "") {
      toast.error(`the k8s version selected '${formData.K8S_V}' is not compatible with the actual versions of CRI supported on this release. Choose a supported k8s version!`);
      return;
    }

    // Call the backend function to create manifests
    const createManifestsResult = clusterCreationBe.createManifests(formData, nodeConfigList);
    if (!createManifestsResult.success) {
      // Show an error notification
      toast.error(createManifestsResult.message);
      return;
    }

    // Create the part of the HAProxy
    const haProxyConfig = clusterCreationBe.createHAProxyConfig(haProxyCommonConfig, haProxyConfigList);

    // Check if haProxyConfig return ok
    if (!haProxyConfig.success) {
      // Show an error notification
      toast.error(haProxyConfig.message);
      return;
    }

    // Call the backend function to create the json
    const createJsonResult = clusterCreationBe.createJson(formData, nodeConfigList, haProxyConfig.result);
    if (!createJsonResult.success) {
      // Show an error notification
      toast.error(createJsonResult.message);
      return;
    }
    
    // Add a file json to the ZIP
    zip.file(`${formData.CLUSTER_NAME}.json`.replace(/-/g, '_'), createJsonResult.result);

    // Add files yaml to the ZIP
    createManifestsResult.result.forEach((item, index) => {
      // Step 3: Add a new file to the JSZip instance
      zip.file(`${item.filename}.yml`.replace(/-/g, '_'), item.file);
    }); 

    // Generate the ZIP file
    zip.generateAsync({ type: 'blob' }).then((content) => {
      saveAs(content, `${formData.CLUSTER_NAME}.zip`.replace(/-/g, '_'));
    });
    
    // Message success
    toast.success('Manifests created successfully!');
  };

  // Node configurations
  const [nodeConfigList, setNodeConfigList] = useState<NodeConfigItemModel[]>([]);

  const handleNodeConfigChange = (index: number, name: keyof NodeConfigItemModel) => (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    const newList = [...nodeConfigList];
    newList[index][name] = event.target.value;
    setNodeConfigList(newList);
  };

  const handleNodeConfigSelectChange = (index: number, name: keyof NodeConfigItemModel) => (
    event: SelectChangeEvent<string>
  ) => {
    const newList = [...nodeConfigList];
    newList[index][name] = event.target.value;
    setNodeConfigList(newList);
  };

  const addNodeConfig = () => {
    setNodeConfigList([...nodeConfigList, getEmptyNodeConfig()]);
  };

  const removeNodeConfig = (index: number) => {
    const newList = [...nodeConfigList];
    newList.splice(index, 1);
    setNodeConfigList(newList);
  };

  const getEmptyNodeConfig = (): NodeConfigItemModel => ({
    ANSIBLE_HOST: '',
    HOSTNAME: '',
    SSH_USER: '', 
    SSH_PASSWORD: '',
    SSH_KEY_PATH: '',
    REQ_PORTS: '',
    OPEN_PORTS: '',
    NODE_TYPE: '',
    NODE_IP: '',
    PHYSICAL_ENV: '',
    MASTER_TYPE: '',
  });  

  // For storj secret
  const [showPasswordStorj, setShowPasswordStorj] = useState(false);

  const handleTogglePasswordVisibilityStorj = () => {
    setShowPasswordStorj(!showPasswordStorj);
  };

  // For ssh password
  const [showPassword, setShowPassword] = useState(false);

  const handleTogglePasswordVisibility = () => {
    setShowPassword(!showPassword);
  };

  // For haproxy password
  const [showPasswordP, setShowPasswordP] = useState(false);

  const handleTogglePasswordVisibilityP = () => {
    setShowPasswordP(!showPasswordP);
  };

  // For username password of haproxy
  const [showPasswordPP, setShowPasswordPP] = useState(false);

  const handleTogglePasswordVisibilityPP = () => {
    setShowPasswordPP(!showPasswordPP);
  };

  // HAProxy 
  const [haProxyConfigList, setHaProxyConfigList] = useState<HAProxy[]>([]);

  const [haProxyCommonConfig, setHaProxyCommonConfig] = useState({
    password: '',
    vip: '',
    sslEnabled: false,
    domain: ''
  });

  const handleHaProxyCommonChange = (name: keyof typeof haProxyCommonConfig) => (event: React.ChangeEvent<HTMLInputElement>) => {
    if (name === 'sslEnabled') {
      // If sslEnabled is being unchecked, also clear the domain field
      const isSslEnabled = event.target.checked;
      setHaProxyCommonConfig({ 
        ...haProxyCommonConfig, 
        sslEnabled: isSslEnabled, 
        domain: isSslEnabled ? haProxyCommonConfig.domain : '' 
      });
    } else {
      // For all other fields, just update the field value
      setHaProxyCommonConfig({ ...haProxyCommonConfig, [name]: event.target.value });
    }
  };

  const getEmptyHaProxyConfig = () => ({
    ip: '',
    lan_interface: '',
    state: '',
    hostname: '',
    router_id: '',
    priority: '',
    ssh_endpoint: '',
    ssh_username: '',
    ssh_password: '',
    ssh_key_path: '',
    physical_env: '',
    internal_or_external: '',
  });

  const handleHaProxySelectConfigChange = 
  (index: number, name: keyof HAProxy) => 
  (event: SelectChangeEvent<string>) => {
    const newList = [...haProxyConfigList];
    newList[index][name] = event.target.value;
    setHaProxyConfigList(newList);
  };

  const handleHaProxyNodeConfigChange = 
  (index: number, name: keyof HAProxy) => 
  (event: React.ChangeEvent<HTMLInputElement>) => {
    const newList = [...haProxyConfigList];
    newList[index][name] = event.target.value;
    setHaProxyConfigList(newList);
  };

  const addHaProxyConfig = () => {
    setHaProxyConfigList([...haProxyConfigList, getEmptyHaProxyConfig()]);
  };

  const removeHaProxyConfig = (index: number) => {
    const newList = [...haProxyConfigList];
    newList.splice(index, 1);
    setHaProxyConfigList(newList);
  };  

  return (
    <Container maxWidth="sm">
      <ToastContainer position="top-right" autoClose={5000} hideProgressBar={false} newestOnTop={false} closeOnClick rtl={false} pauseOnFocusLoss draggable pauseOnHover />
      <br/>
      <Typography variant="h5" gutterBottom>
        <strong>Cluster Configuration</strong>
      </Typography>
      <form>
        {/* Cluster configuration */}  
        <div>
          <TextField
            label="Cluster Name"
            value={formData.CLUSTER_NAME}
            onChange={handleChange('CLUSTER_NAME')}
            fullWidth
            margin="normal"
            required
          />
          <TextField
            label="Storj Export"
            type={showPasswordStorj ? 'text' : 'password'}
            value={formData.STORJ_SECRET}
            onChange={handleChange('STORJ_SECRET')}
            fullWidth
            margin="normal"
            required
            InputProps={{
              endAdornment: (
                <InputAdornment position="end">
                  <IconButton
                    aria-label="toggle password visibility"
                    onClick={handleTogglePasswordVisibilityStorj}
                    edge="end"
                  >
                    {showPasswordStorj ? <Visibility /> : <VisibilityOff />}
                  </IconButton>
                </InputAdornment>
              )
            }}
          />
          <TextField
            label="Storj Bucket"
            value={formData.STORJ_BUCKET}
            onChange={handleChange('STORJ_BUCKET')}
            fullWidth
            margin="normal"
            required
          />
          <TextField
            label="Pod CIDR"
            value={formData.POD_CIDR}
            onChange={handleChange('POD_CIDR')}
            fullWidth
            margin="normal"
            required
          />         
          <FormControl fullWidth margin="normal" required>
            <InputLabel id="k8s-version-label">K8s Version</InputLabel>
            <Select
              labelId="k8s-version-label"
              id="k8s-version"
              value={formData.K8S_V}
              onChange={handleSelectChange('K8S_V')}
              required
            >
              <MenuItem value="1.28.4-1.1">1.28.4</MenuItem>
              <MenuItem value="1.28.2-00">1.28.2</MenuItem>
            </Select>
          </FormControl>
          <FormControl fullWidth margin="normal" required>
            <InputLabel id="cri-os-label">OS</InputLabel>
            <Select
              labelId="cri-os-label"
              id="cri-os"
              value={formData.CRI_OS}
              onChange={handleSelectChange('CRI_OS')}
              required
            >
              <MenuItem value="xUbuntu_22.04">Ubuntu Server 22.04</MenuItem>
            </Select>
          </FormControl>
          <FormControl fullWidth margin="normal" required>
            <InputLabel id="env-label">Ports Env</InputLabel>
            <Select
              labelId="env-label"
              id="env"
              value={formData.ENV}
              onChange={handleSelectChange('ENV')}
              required
            >
              <MenuItem value="prod">prod</MenuItem>
              <MenuItem value="dev">dev</MenuItem>
            </Select>
          </FormControl>
          <TextField
            label="Project Git Path"
            value={formData.PROJECT_GIT_PATH}
            onChange={handleChange('PROJECT_GIT_PATH')}
            fullWidth
            margin="normal"
            required
          />
        </div>

        <br/>
        
        {/* Node configuration */}  
        <div>
          {nodeConfigList.map((nodeConfig, index) => (
            <Box key={index} mb={2}>
              <Typography variant="h6" gutterBottom>
                Node Configuration {index + 1}           
              </Typography>
              <TextField
                label="Hostname"
                value={nodeConfig.HOSTNAME}
                onChange={handleNodeConfigChange(index, 'HOSTNAME')}
                fullWidth
                margin="normal"
                required
              />
              <TextField
                label="Ip"
                value={nodeConfig.NODE_IP}
                onChange={handleNodeConfigChange(index, 'NODE_IP')}
                fullWidth
                margin="normal"
                required
              />
              <TextField
                label="Physical Environment"
                value={nodeConfig.PHYSICAL_ENV}
                onChange={handleNodeConfigChange(index, 'PHYSICAL_ENV')}
                fullWidth
                margin="normal"
                required
              />
              <TextField
                label="Ssh endpoint"
                value={nodeConfig.ANSIBLE_HOST}
                onChange={handleNodeConfigChange(index, 'ANSIBLE_HOST')}
                fullWidth
                margin="normal"
                required
              />
              <TextField
                label="Ssh Username"
                value={nodeConfig.SSH_USER}
                onChange={handleNodeConfigChange(index, 'SSH_USER')}
                fullWidth
                margin="normal"
                required
              />
              <TextField
                label="Ssh Password"
                type={showPassword ? 'text' : 'password'}
                value={nodeConfig.SSH_PASSWORD}
                onChange={handleNodeConfigChange(index, 'SSH_PASSWORD')}
                fullWidth
                margin="normal"
                required
                InputProps={{
                  endAdornment: (
                    <InputAdornment position="end">
                      <IconButton onClick={handleTogglePasswordVisibility} edge="end">
                        {showPassword ? <Visibility /> : <VisibilityOff />}
                      </IconButton>
                    </InputAdornment>
                  ),
                }}
              />
              <TextField
                label="Ssh Key Path"
                value={nodeConfig.SSH_KEY_PATH}
                onChange={handleNodeConfigChange(index, 'SSH_KEY_PATH')}
                fullWidth
                margin="normal"
                required
              />
              <FormControl fullWidth margin="normal" required>
                <InputLabel id="node-type-label">Node Type</InputLabel>
                <Select
                  labelId="node-type-label"
                  id="node-type"
                  value={nodeConfig.NODE_TYPE}
                  onChange={handleNodeConfigSelectChange(index, 'NODE_TYPE')}
                  required
                >
                  <MenuItem value="master">master</MenuItem>
                  <MenuItem value="worker">worker</MenuItem>
                </Select>
              </FormControl>
              <FormControl fullWidth margin="normal" required>
                <InputLabel id="req-ports-label">Require Network Ports Configuration</InputLabel>
                <Select
                  labelId="req-ports-label"
                  id="req-ports"
                  value={nodeConfig.REQ_PORTS}
                  onChange={handleNodeConfigSelectChange(index, 'REQ_PORTS')}
                  required
                >
                  <MenuItem value="true">true</MenuItem>
                  <MenuItem value="false">false</MenuItem>
                </Select>
              </FormControl>
              <FormControl fullWidth margin="normal" required>
                <InputLabel id="open-ports-label">Network Ports To Open</InputLabel>
                <Select
                  labelId="open-ports-label"
                  id="open-ports"
                  value={nodeConfig.OPEN_PORTS}
                  onChange={handleNodeConfigSelectChange(index, 'OPEN_PORTS')}
                  required
                >
                  <MenuItem value="master">master</MenuItem>
                  <MenuItem value="worker">worker</MenuItem>
                  <MenuItem value="both">both</MenuItem>
                  <MenuItem value="all">all</MenuItem>
                </Select>
              </FormControl>
              <FormControl fullWidth margin="normal" required>
                <InputLabel id="open-ports-label">Master Type (only for HAProxy enabeld and master nodes)</InputLabel>
                <Select
                  labelId="open-ports-label"
                  id="open-ports"
                  value={nodeConfig.MASTER_TYPE}
                  onChange={handleNodeConfigSelectChange(index, 'MASTER_TYPE')}
                  required
                >
                  <MenuItem value="not_configured">Not Configured</MenuItem>
                  <MenuItem value="master">master</MenuItem>
                  <MenuItem value="backup">backup</MenuItem>
                </Select>
              </FormControl>
              <br/>
              <Button variant="outlined" color="error" onClick={() => removeNodeConfig(index)}>
                Remove Node
              </Button>
              <br/><br/>
            </Box>
          ))}

          <Button variant="outlined" onClick={addNodeConfig}>
            Add Node Configuration
          </Button>          
        </div>

        <br/><br/><br/>

        {/* HA Proxy configuration */}        
        <div>
          <Typography variant="h5" gutterBottom>
            <strong>HAProxy Common Configuration</strong>
          </Typography>
          <TextField
            label="HAProxy Virtual IP (VIP)"
            value={haProxyCommonConfig.vip}
            onChange={handleHaProxyCommonChange('vip')}
            fullWidth
            margin="normal"
            required
          />
          <TextField
            label="HAProxy Password"
            type={showPasswordP ? 'text' : 'password'}
            value={haProxyCommonConfig.password}
            onChange={handleHaProxyCommonChange('password')}
            fullWidth
            margin="normal"
            required
            InputProps={{
              endAdornment: (
                <InputAdornment position="end">
                  <IconButton
                    aria-label="toggle password visibility"
                    onClick={handleTogglePasswordVisibilityP}
                    edge="end"
                  >
                    {showPasswordP ? <Visibility /> : <VisibilityOff />}
                  </IconButton>
                </InputAdornment>
              )
            }}
          />
          <FormControlLabel
            control={
              <Checkbox
                checked={haProxyCommonConfig.sslEnabled}
                onChange={handleHaProxyCommonChange('sslEnabled')}
                name="sslEnabled"
              />
            }
            label="SSL Enabled"
          />
          {haProxyCommonConfig.sslEnabled && (
            <TextField
              label="Domain for SSL Certificate"
              value={haProxyCommonConfig.domain}
              onChange={handleHaProxyCommonChange('domain')}
              fullWidth
              margin="normal"
              required={haProxyCommonConfig.sslEnabled}
            />
          )}
          
          <br/><br/>
          
          {haProxyConfigList.map((config, index) => (
            <Box key={index} mb={2}>
              <Typography variant="h6" gutterBottom>
                HAProxy Node Configuration {index + 1}
              </Typography>
              <TextField
                label="Hostname"
                value={config.hostname}
                onChange={handleHaProxyNodeConfigChange(index, 'hostname')}
                fullWidth
                margin="normal"
                required
              />
              <TextField
                label="LAN Interface"
                value={config.lan_interface}
                onChange={handleHaProxyNodeConfigChange(index, 'lan_interface')}
                fullWidth
                margin="normal"
                required
              />
              <TextField
                label="IP Address"
                value={config.ip}
                onChange={handleHaProxyNodeConfigChange(index, 'ip')}
                fullWidth
                margin="normal"
                required
              />
              <TextField
                label="Router ID"
                value={config.router_id}
                onChange={handleHaProxyNodeConfigChange(index, 'router_id')}
                fullWidth
                margin="normal"
                required
              />
              <TextField
                label="Priority"
                value={config.priority}
                onChange={handleHaProxyNodeConfigChange(index, 'priority')}
                fullWidth
                margin="normal"
                required
              />
              <TextField
                label="SSH Endpoint"
                value={config.ssh_endpoint}
                onChange={handleHaProxyNodeConfigChange(index, 'ssh_endpoint')}
                fullWidth
                margin="normal"
                required
              />
              <TextField
                label="SSH Username"
                value={config.ssh_username}
                onChange={handleHaProxyNodeConfigChange(index, 'ssh_username')}
                fullWidth
                margin="normal"
                required
              />
              <TextField
                label="SSH Password"
                type={showPasswordPP ? 'text' : 'password'}
                value={config.ssh_password}
                onChange={handleHaProxyNodeConfigChange(index, 'ssh_password')}
                fullWidth
                margin="normal"
                required
                InputProps={{
                  endAdornment: (
                    <InputAdornment position="end">
                      <IconButton onClick={handleTogglePasswordVisibilityPP} edge="end">
                        {showPasswordPP ? <Visibility /> : <VisibilityOff />}
                      </IconButton>
                    </InputAdornment>
                  ),
                }}
              />
              <TextField
                label="SSH Key Path"
                value={config.ssh_key_path}
                onChange={handleHaProxyNodeConfigChange(index, 'ssh_key_path')}
                fullWidth
                margin="normal"
                required
              />
              <TextField
                label="Physical Environment"
                value={config.physical_env}
                onChange={handleHaProxyNodeConfigChange(index, 'physical_env')}
                fullWidth
                margin="normal"
                required
              />
              <FormControl fullWidth margin="normal" required>
                <InputLabel id={`state-label-${index}`}>State</InputLabel>
                <Select
                  labelId={`state-label-${index}`}
                  id={`state-${index}`}
                  value={config.state}
                  onChange={handleHaProxySelectConfigChange(index, 'state')}
                  required
                >
                  <MenuItem value="MASTER">MASTER</MenuItem>
                  <MenuItem value="BACKUP">BACKUP</MenuItem>
                </Select>
              </FormControl>
              <FormControl fullWidth margin="normal" required>
                <InputLabel id={`ie-label-${index}`}>Internal or External</InputLabel>
                <Select
                  labelId={`ie-label-${index}`}
                  id={`ie-${index}`}
                  value={config.internal_or_external}
                  onChange={handleHaProxySelectConfigChange(index, 'internal_or_external')}
                  required
                >
                  <MenuItem value="external">External</MenuItem>
                  <MenuItem value="internal">Internal</MenuItem>
                </Select>
              </FormControl>
              <br/>
              <Button variant="outlined" color="error" onClick={() => removeHaProxyConfig(index)}>
                Remove HAProxy Node
              </Button>
              <br/><br/>
            </Box>
          ))}

          <Button variant="outlined" onClick={addHaProxyConfig}>
            Add HAProxy Node Configuration
          </Button>
        </div>

        <br/><br/>

        <Button variant="contained" color="primary" onClick={handleSubmit} style={{ marginLeft: 'auto', display: 'block' }}>
          Generate Manifests
        </Button>
        
        <br/>
      </form>
    </Container>
  );
};

export default ClusterCreation;
