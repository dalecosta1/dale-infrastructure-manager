import React, { useState } from 'react';
import { BrowserRouter as Router } from 'react-router-dom';
import { AppBar, Toolbar, IconButton, Typography } from '@mui/material';
import MenuIcon from '@mui/icons-material/Menu';
import NavigationMenu from './components/NavigationMenu';
import AppRoutes from './Routes';

const App: React.FC = () => {
  const [menuOpen, setMenuOpen] = useState(false);

  const handleMenuOpen = () => {
    setMenuOpen(true);
  };

  const handleMenuClose = () => {
    setMenuOpen(false);
  };

  return (
    <Router>
      <div>
        <AppBar position="static">
          <Toolbar>
            <IconButton onClick={handleMenuOpen} edge="start" color="inherit" aria-label="menu">
              <MenuIcon />
            </IconButton>
            <Typography variant="h6" component="div" style={{ flexGrow: 1, marginLeft: '10px' }}>
              DALE INFRASTRUCTURE MANAGER
            </Typography>
          </Toolbar>
        </AppBar>
        <NavigationMenu open={menuOpen} onClose={handleMenuClose} />
        <AppRoutes />
      </div>
    </Router>
  );
};

export default App;
