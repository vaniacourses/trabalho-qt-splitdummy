// fullstack_app/client/src/components/groups/GroupMembersManager.tsx
import React, { useState, useEffect } from 'react';
import api from '../../services/api';

interface User {
  id: number;
  name: string;
  email: string;
}

interface GroupMembership {
  id: number;
  user: User;
  status: string;
  joined_at: string;
}

interface GroupMembersManagerProps {
  groupId: number;
  currentMemberships: GroupMembership[];
  isCreator: boolean;
  onMembersUpdated: () => void;
}

const GroupMembersManager: React.FC<GroupMembersManagerProps> = ({ 
  groupId, 
  currentMemberships, 
  isCreator,
  onMembersUpdated 
}) => {
  const [searchTerm, setSearchTerm] = useState('');
  const [searchResults, setSearchResults] = useState<User[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [addingMember, setAddingMember] = useState(false);

  const searchUsers = async (term: string) => {
    if (term.length < 2) {
      setSearchResults([]);
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const response = await api.get<User[]>(`/users?search=${encodeURIComponent(term)}`);
      // Filtra usuários que já são membros do grupo
      const existingMemberIds = currentMemberships.map(m => m.user.id);
      const filteredResults = response.data.filter(user => !existingMemberIds.includes(user.id));
      setSearchResults(filteredResults);
    } catch (err: any) {
      console.error('Erro ao buscar usuários', err);
      setError('Erro ao buscar usuários.');
    }
    setLoading(false);
  };

  useEffect(() => {
    const timeoutId = setTimeout(() => {
      if (searchTerm) {
        searchUsers(searchTerm);
      } else {
        setSearchResults([]);
      }
    }, 300); // Debounce de 300ms

    return () => clearTimeout(timeoutId);
  }, [searchTerm]);

  const handleAddMember = async (userId: number) => {
    setAddingMember(true);
    setError(null);
    try {
      await api.post(`/groups/${groupId}/group_memberships`, { user_id: userId });
      setSearchTerm('');
      setSearchResults([]);
      onMembersUpdated();
    } catch (err: any) {
      console.error('Erro ao adicionar membro', err);
      setError(err.response?.data?.errors?.[0] || err.response?.data?.message || 'Erro ao adicionar membro.');
    }
    setAddingMember(false);
  };

  const handleRemoveMember = async (membershipId: number, userName: string) => {
    if (!window.confirm(`Tem certeza que deseja remover ${userName} do grupo?`)) {
      return;
    }

    setError(null);
    try {
      await api.delete(`/groups/${groupId}/group_memberships/${membershipId}`);
      onMembersUpdated();
    } catch (err: any) {
      console.error('Erro ao remover membro', err);
      setError(err.response?.data?.errors?.[0] || err.response?.data?.message || 'Erro ao remover membro.');
    }
  };

  if (!isCreator) {
    return (
      <div className="group-members-manager">
        <h3>Membros do Grupo</h3>
        <ul className="members-list">
          {currentMemberships.map(membership => (
            <li key={membership.id} className="member-item">
              <span>{membership.user.name} ({membership.user.email})</span>
              {membership.status === 'active' && <span className="status-badge active">Ativo</span>}
              {membership.status === 'inactive' && <span className="status-badge inactive">Inativo</span>}
            </li>
          ))}
        </ul>
      </div>
    );
  }

  return (
    <div className="group-members-manager">
      <h3>Gerenciar Membros do Grupo</h3>
      
      {error && <p className="error-message">{error}</p>}

      <div className="add-member-section">
        <h4>Adicionar Novo Membro</h4>
        <input
          type="text"
          placeholder="Buscar usuário por nome ou email..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="member-search-input"
        />
        
        {loading && <p>Buscando...</p>}
        
        {searchResults.length > 0 && (
          <ul className="search-results">
            {searchResults.map(user => (
              <li key={user.id} className="search-result-item">
                <span>{user.name} ({user.email})</span>
                <button 
                  onClick={() => handleAddMember(user.id)}
                  disabled={addingMember}
                  className="add-member-btn"
                >
                  {addingMember ? 'Adicionando...' : 'Adicionar'}
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>

      <div className="current-members-section">
        <h4>Membros Atuais</h4>
        <ul className="members-list">
          {currentMemberships.map(membership => (
            <li key={membership.id} className="member-item">
              <span>{membership.user.name} ({membership.user.email})</span>
              <div className="member-actions">
                {membership.status === 'active' && <span className="status-badge active">Ativo</span>}
                {membership.status === 'inactive' && <span className="status-badge inactive">Inativo</span>}
                <button 
                  onClick={() => handleRemoveMember(membership.id, membership.user.name)}
                  className="remove-member-btn"
                >
                  Remover
                </button>
              </div>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
};

export default GroupMembersManager;

