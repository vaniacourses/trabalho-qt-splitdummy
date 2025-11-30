// fullstack_app/client/src/services/api.ts
import axios from 'axios';

const api = axios.create({
  baseURL: '', // Base URL vazia para que as chamadas correspondam às rotas do proxy no Vite
  withCredentials: true, // Importante para enviar e receber cookies de sessão
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  },
});

export default api;
