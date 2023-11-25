import React from 'react';
import { Routes, Route } from 'react-router-dom';
import Home from './pages/Home';
import Dashboard from './pages/Dashboard';
import Settings from './pages/Settings';
import ClusterCreation from './pages/ClusterCreation';
import ToolsInstallation from './pages/ToolsInstallation';

const AppRoutes: React.FC = () => {
  return (
    <Routes>
      <Route path="/" element={<Home />} />
      <Route path="/home" element={<Home />} />
      <Route path="/dashboard" element={<Dashboard />} />
      <Route path="/settings" element={<Settings />} />
      <Route path="/k8s-cluster-creation" element={<ClusterCreation />} />
      <Route path="/k8s-tools-installation" element={<ToolsInstallation />} />
    </Routes>
  );
};

export default AppRoutes;
