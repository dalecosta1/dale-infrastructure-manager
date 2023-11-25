import React from 'react';
import { Button, Typography, Paper } from '@mui/material';
import { useNavigate } from 'react-router-dom';

const Home: React.FC = () => {
  const navigate = useNavigate();

  const navigateTo = (route: string) => {
    // Use React Router's navigate function
    navigate(route);
  };

  return (
    <Paper style={{ padding: '20px', margin: '20px' }}>
      <Typography variant="h4"><strong>Create a new Kubernetes cluster</strong></Typography>
      <br/>
      <Button
        onClick={() => navigateTo('/k8s-cluster-creation')}
        variant="contained"
        color="primary"
      >
        Press here to start
      </Button>
      
      {/* Release version description */}
      <Paper elevation={3} style={{ marginTop: '20px', padding: '10px' }}>
        <Typography variant="h6"><strong>v0.1.0</strong> 🚩</Typography>
        <br/>
        <Typography variant="body1" paragraph>
          ✔️ K8s cluster creation feature implementation using kubeadm, ansible and bash.
        </Typography>
        <Typography variant="body1" paragraph>
          ✔️ Implemented the feature to add new nodes to the cluster.
        </Typography>
        <Typography variant="body1" paragraph>
          ✔️ UI implementation to generate manifests and json easily.
        </Typography>
        <Typography variant="body1" paragraph>
          ✔️ Error handling, bugfix and code review.
        </Typography>
      </Paper>
    </Paper>
  );
};

export default Home;
