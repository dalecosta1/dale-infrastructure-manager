// NavigationMenu.tsx
import React from 'react';
import { Drawer, List, ListItem, ListItemIcon, ListItemText } from '@mui/material';
import RocketLaunchIcon from '@mui/icons-material/RocketLaunch';
import ConstructionIcon from '@mui/icons-material/Construction';
import HomeIcon from '@mui/icons-material/Home';
import DashboardIcon from '@mui/icons-material/Dashboard';
import SettingsIcon from '@mui/icons-material/Settings';
import { useNavigate } from 'react-router-dom';

interface NavigationMenuProps {
  open: boolean;
  onClose: () => void;
}

const NavigationMenu: React.FC<NavigationMenuProps> = ({ open, onClose }) => {
  const navigate = useNavigate();

  const navigateTo = (route: string) => {
    // Use React Router's navigate function
    navigate(route);
    onClose(); // Close the menu after navigation
  };

  const listItemStyle: React.CSSProperties = {
    cursor: 'pointer', // Set the cursor to pointer on hover
  };

  return (
    <Drawer anchor="left" open={open} onClose={onClose}>
      <List>
        {/* home */}
        <ListItem style={listItemStyle} onClick={() => navigateTo('/home')}>
          <ListItemIcon>
            <HomeIcon />
          </ListItemIcon>
          <ListItemText primary="Home" />
        </ListItem>

        {/* cluster creation */}        
        <ListItem style={listItemStyle} onClick={() => navigateTo('/k8s-cluster-creation')}>
          <ListItemIcon>
            <RocketLaunchIcon />
          </ListItemIcon>
          <ListItemText primary="Cluster creation" />
        </ListItem>

        {/* tools installation
        <ListItem style={listItemStyle} onClick={() => navigateTo('/k8s-tools-installation')}>
          <ListItemIcon>
            <ConstructionIcon />
          </ListItemIcon>
          <ListItemText primary="Tools installation" />
        </ListItem> */}

        {/* dashboard 
        <ListItem style={listItemStyle} onClick={() => navigateTo('/dashboard')}>
          <ListItemIcon>
            <DashboardIcon />
          </ListItemIcon>
          <ListItemText primary="Dashboard" />
        </ListItem>*/}

        {/* settings */}
        <ListItem style={listItemStyle} onClick={() => navigateTo('/settings')}>
          <ListItemIcon>
            <SettingsIcon />
          </ListItemIcon>
          <ListItemText primary="Settings" />
        </ListItem>
      </List>
    </Drawer>
  );
};

export default NavigationMenu;
