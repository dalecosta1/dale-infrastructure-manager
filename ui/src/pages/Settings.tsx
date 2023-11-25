import React from 'react';
import { Typography } from '@mui/material';
import packageJson from '../../package.json'; // Adjust the path based on your project structure

const Settings: React.FC = () => {
  const version = packageJson.version;

  return (
    <div style={{ padding: '20px' }}>
    <Typography variant="h4"><strong>Settings</strong></Typography>
    <br/>
    <p>Version: <span style={{ fontWeight: 'bold' }}>v{version}</span></p>
    </div>
  );
};

export default Settings;
