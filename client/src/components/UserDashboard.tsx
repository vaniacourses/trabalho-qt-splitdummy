// fullstack_app/client/src/components/UserDashboard.tsx
import React, { useState, useEffect } from 'react';
import api from '../services/api';
import GroupList from './groups/GroupList';
import GroupForm from './groups/GroupForm';
import GroupDetailsView from './groups/GroupDetailsView'; // Importa o novo componente

interface User {
  id: number;
  name: string;
  email: string;
  default_currency: string;
}

interface Group {
  id: number;
  name: string;
  description: string;
  group_type: string;
  creator: User;
}

interface UserDashboardProps {
  currentUser: User;
  onLogout: () => void;
}

const UserDashboard: React.FC<UserDashboardProps> = ({ currentUser, onLogout }) => {
  const [selectedGroup, setSelectedGroup] = useState<Group | null>(null);
  const [isCreatingGroup, setIsCreatingGroup] = useState(false);
  const [isEditingGroup, setIsEditingGroup] = useState(false);

  const handleGroupCreated = () => {
    setIsCreatingGroup(false);
    setIsEditingGroup(false);
    setSelectedGroup(null);
    // Força a atualização da lista de grupos (poderíamos passar uma prop para GroupList recarregar)
  };

  const handleGroupSelected = (group: Group) => {
    setSelectedGroup(group);
    setIsCreatingGroup(false);
    setIsEditingGroup(false);
  };

  const handleEditGroup = () => {
    setIsEditingGroup(true);
    setIsCreatingGroup(false);
  };

  const handleCancelForm = () => {
    setIsCreatingGroup(false);
    setIsEditingGroup(false);
    setSelectedGroup(null);
  };

  return (
    <div className="user-dashboard">
      <header className="dashboard-header">
        <h1>Bem-vindo, {currentUser.name}!</h1>
        <button onClick={onLogout}>Sair</button>
      </header>

      <nav className="dashboard-nav">
        <button onClick={() => {
          setIsCreatingGroup(false);
          setIsEditingGroup(false);
          setSelectedGroup(null);
        }}>Ver Grupos</button>
        {selectedGroup && <button onClick={handleEditGroup}>Editar Grupo</button>}
      </nav>

      <main className="dashboard-main">
        {isCreatingGroup ? (
          <GroupForm onFormSubmit={handleGroupCreated} onCancel={handleCancelForm} />
        ) : isEditingGroup && selectedGroup ? (
          <GroupForm existingGroup={selectedGroup} onFormSubmit={handleGroupCreated} onCancel={handleCancelForm} />
        ) : (
          <GroupList onGroupSelected={handleGroupSelected} onGroupCreated={() => setIsCreatingGroup(true)} />
        )}

        {selectedGroup && !isCreatingGroup && !isEditingGroup && (
          <GroupDetailsView group={selectedGroup} currentUser={currentUser} onBackToList={handleCancelForm} />
        )}
      </main>
    </div>
  );
};

export default UserDashboard;
