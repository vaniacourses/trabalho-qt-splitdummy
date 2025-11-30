// fullstack_app/client/src/components/groups/GroupList.tsx
import React, { useEffect, useState } from 'react';
import api from '../../services/api';

interface User {
  id: number;
  name: string;
  email: string;
}

interface Group {
  id: number;
  name: string;
  description: string;
  group_type: string;
  creator: User;
}

interface GroupListProps {
  onGroupSelected: (group: Group) => void;
  onGroupCreated: () => void;
}

const GroupList: React.FC<GroupListProps> = ({ onGroupSelected, onGroupCreated }) => {
  const [groups, setGroups] = useState<Group[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchGroups = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await api.get<Group[]>('/groups');
      setGroups(response.data);
    } catch (err: any) {
      console.error('Erro ao buscar grupos', err);
      setError(err.response?.data?.message || 'Erro ao carregar grupos.');
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchGroups();
  }, []);

  const handleDeleteGroup = async (groupId: number) => {
    if (window.confirm('Tem certeza que deseja excluir este grupo?')) {
      try {
        await api.delete(`/groups/${groupId}`);
        fetchGroups(); // Recarrega a lista após a exclusão
      } catch (err: any) {
        console.error('Erro ao excluir grupo', err);
        setError(err.response?.data?.message || 'Erro ao excluir grupo.');
      }
    }
  };

  if (loading) {
    return <p>Carregando grupos...</p>;
  }

  if (error) {
    return <p className="error-message">{error}</p>;
  }

  return (
    <div className="group-list">
      <h2>Meus Grupos</h2>
      <button onClick={onGroupCreated}>Criar Novo Grupo</button>
      {groups.length === 0 ? (
        <p>Você não está em nenhum grupo ainda.</p>
      ) : (
        <ul>
          {groups.map((group) => (
            <li key={group.id} className="group-item">
              <span onClick={() => onGroupSelected(group)}>{group.name}</span>
              <button onClick={() => handleDeleteGroup(group.id)}>Excluir</button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
};

export default GroupList;
