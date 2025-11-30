import React, { useState, useEffect } from 'react';
import api from './services/api';
import RegisterForm from './components/auth/RegisterForm';
import LoginForm from './components/auth/LoginForm';
import UserDashboard from './components/UserDashboard';
import './App.css';

interface User {
  id: number;
  name: string;
  email: string;
  default_currency: string;
}

function App() {
  const [loggedInStatus, setLoggedInStatus] = useState('NOT_LOGGED_IN');
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [showRegister, setShowRegister] = useState(false);
  const [loading, setLoading] = useState(true);

  const checkLoginStatus = async () => {
    try {
      const response = await api.get('/logged_in');
      if (response.data.logged_in && response.data.user) {
        setLoggedInStatus('LOGGED_IN');
        setCurrentUser(response.data.user);
      } else {
        setLoggedInStatus('NOT_LOGGED_IN');
        setCurrentUser(null);
      }
    } catch (err) {
      console.error('Erro ao verificar status de login', err);
      setLoggedInStatus('NOT_LOGGED_IN');
      setCurrentUser(null);
    }
    setLoading(false);
  };

  useEffect(() => {
    checkLoginStatus();
  }, []);

  const handleLoginSuccess = () => {
    checkLoginStatus();
  };

  const handleRegisterSuccess = () => {
    checkLoginStatus();
  };

  const handleLogout = async () => {
    try {
      await api.delete('/logout');
      setLoggedInStatus('NOT_LOGGED_IN');
      setCurrentUser(null);
      setShowRegister(false);
    } catch (err) {
      console.error('Erro ao fazer logout', err);
    }
  };

  if (loading) {
    return <div className="App">Carregando...</div>;
  }

  return (
    <div className="App">
      {loggedInStatus === 'LOGGED_IN' && currentUser ? (
        <UserDashboard currentUser={currentUser} onLogout={handleLogout} />
      ) : (
        <div className="auth-container">
          <h1>Bem-vindo ao Sistema de Divisão de Contas!</h1>
          {showRegister ? (
            <RegisterForm onRegisterSuccess={handleRegisterSuccess} />
          ) : (
            <LoginForm onLoginSuccess={handleLoginSuccess} />
          )}
          <button onClick={() => setShowRegister(!showRegister)} className="toggle-auth-mode">
            {showRegister ? 'Já tem uma conta? Faça Login' : 'Não tem uma conta? Registre-se'}
          </button>
      </div>
      )}
      </div>
  );
}

export default App;
