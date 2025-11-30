// fullstack_app/client/src/components/expenses/ExpenseForm.tsx
import React, { useState, useEffect } from 'react';
import api from '../../services/api';

interface User {
  id: number;
  name: string;
  email: string;
}

interface GroupMember extends User {
  status: string;
}

interface ExpenseParticipant {
  id?: number;
  user: User;
  amount_owed: string; // Usar string para entrada para evitar problemas de ponto flutuante
}

interface Expense {
  id?: number;
  description: string;
  total_amount: string; // Usar string para entrada
  payer: User;
  group_id: number;
  expense_date: string; // Formato YYYY-MM-DD
  currency: string;
  expense_participants: ExpenseParticipant[];
}

interface ExpenseFormProps {
  groupId: number;
  groupMembers: GroupMember[]; // Membros do grupo para seleção de participantes
  existingExpense?: Expense | null;
  onFormSubmit: () => void;
  onCancel: () => void;
}

const ExpenseForm: React.FC<ExpenseFormProps> = ({ groupId, groupMembers, existingExpense, onFormSubmit, onCancel }) => {
  const [description, setDescription] = useState(existingExpense?.description || '');
  const [totalAmount, setTotalAmount] = useState(existingExpense?.total_amount || '');
  const [expenseDate, setExpenseDate] = useState(existingExpense?.expense_date || new Date().toISOString().split('T')[0]);
  const [currency, setCurrency] = useState(existingExpense?.currency || 'BRL');
  const [splittingMethod, setSplittingMethod] = useState('equally');
  const [participantsInput, setParticipantsInput] = useState<{
    [userId: number]: { percentage?: string; weight?: string; fixed_amount?: string; selected: boolean };
  }>({});
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    // Inicializa os participantes quando o componente é montado ou um existingExpense é fornecido
    const initialParticipantsInput: { [userId: number]: any } = {};
    groupMembers.forEach(member => {
      initialParticipantsInput[member.id] = { selected: false };
    });

    if (existingExpense) {
      setDescription(existingExpense.description);
      setTotalAmount(existingExpense.total_amount);
      setExpenseDate(existingExpense.expense_date);
      setCurrency(existingExpense.currency);

      // Tenta inferir o método de divisão e preencher participantes
      // Simplificado: por enquanto, apenas marcamos os participantes existentes como selecionados
      existingExpense.expense_participants.forEach(ep => {
        if (initialParticipantsInput[ep.user.id]) {
          initialParticipantsInput[ep.user.id] = { ...initialParticipantsInput[ep.user.id], selected: true, fixed_amount: ep.amount_owed };
        }
      });
      // Se for uma edição, e todos os participantes tiverem quantias iguais, pode ser igualmente
      // Se a soma das porcentagens ou pesos for 100/total, inferir.
      // Por complexidade, vamos deixar o usuário escolher ao editar.

      // Exemplo simples de como inferir 'fixed_amounts' se todos tiverem 'amount_owed'
      setSplittingMethod('fixed_amounts'); // Assume fixed_amounts para edição para simplificar
    }
    setParticipantsInput(initialParticipantsInput);
  }, [existingExpense, groupMembers]);

  const handleParticipantSelection = (userId: number, selected: boolean) => {
    setParticipantsInput(prev => ({
      ...prev,
      [userId]: { ...prev[userId], selected }
    }));
  };

  const handleSplittingParamChange = (userId: number, paramType: 'percentage' | 'weight' | 'fixed_amount', value: string) => {
    setParticipantsInput(prev => ({
      ...prev,
      [userId]: { ...prev[userId], [paramType]: value }
    }));
  };

  const calculateRemainingAmount = () => {
    const total = parseFloat(totalAmount || '0');
    let allocated = 0;
    if (splittingMethod === 'fixed_amounts') {
      Object.values(participantsInput).forEach(p => {
        if (p.selected && p.fixed_amount) {
          allocated += parseFloat(p.fixed_amount);
        }
      });
    } else if (splittingMethod === 'percentages') {
      Object.values(participantsInput).forEach(p => {
        if (p.selected && p.percentage) {
          allocated += (total * parseFloat(p.percentage) / 100);
        }
      });
    } else if (splittingMethod === 'weights') {
      const totalWeight = Object.values(participantsInput).reduce((sum, p) => sum + (p.selected && p.weight ? parseFloat(p.weight) : 0), 0);
      Object.values(participantsInput).forEach(p => {
        if (p.selected && p.weight && totalWeight > 0) {
          allocated += (total * parseFloat(p.weight) / totalWeight);
        }
      });
    }
    return (total - allocated).toFixed(2);
  };

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const selectedParticipants = Object.keys(participantsInput)
        .filter(userId => participantsInput[parseInt(userId)].selected)
        .map(userId => parseInt(userId));

      if (!selectedParticipants.length) {
        setError('Selecione pelo menos um participante.');
        setLoading(false);
        return;
      }

      const expenseData: any = {
        description,
        total_amount: parseFloat(totalAmount).toFixed(2), // Garante duas casas decimais
        expense_date: expenseDate,
        currency,
        splitting_method: splittingMethod,
      };

      if (splittingMethod === 'percentages') {
        const percentages: { [userId: number]: number } = {};
        let totalPercentage = 0;
        selectedParticipants.forEach(userId => {
          const percentage = parseFloat(participantsInput[userId]?.percentage || '0');
          percentages[userId] = percentage;
          totalPercentage += percentage;
        });
        if (totalPercentage !== 100 && splittingMethod === 'percentages') {
          setError('A soma das porcentagens deve ser 100%.');
          setLoading(false);
          return;
        }
        expenseData.splitting_params = { percentages };
      } else if (splittingMethod === 'weights') {
        const weights: { [userId: number]: number } = {};
        let totalWeight = 0;
        selectedParticipants.forEach(userId => {
          const weight = parseFloat(participantsInput[userId]?.weight || '0');
          weights[userId] = weight;
          totalWeight += weight;
        });
        if (totalWeight <= 0 && splittingMethod === 'weights') {
          setError('A soma dos pesos deve ser maior que zero.');
          setLoading(false);
          return;
        }
        expenseData.splitting_params = { weights };
      } else if (splittingMethod === 'fixed_amounts') {
        const amounts: { [userId: number]: number } = {};
        let totalFixedAmount = 0;
        selectedParticipants.forEach(userId => {
          const amount = parseFloat(participantsInput[userId]?.fixed_amount || '0');
          amounts[userId] = amount;
          totalFixedAmount += amount;
        });
        if (totalFixedAmount.toFixed(2) !== parseFloat(totalAmount).toFixed(2)) {
          setError(`A soma dos valores fixos (${totalFixedAmount.toFixed(2)}) não corresponde ao total da despesa (${parseFloat(totalAmount).toFixed(2)}).`);
          setLoading(false);
          return;
        }
        expenseData.splitting_params = { amounts };
      } else if (splittingMethod === 'equally') {
        // Não precisa de splitting_params para divisão igualmente
      }

      let response;
      if (existingExpense) {
        response = await api.patch(`/groups/${groupId}/expenses/${existingExpense.id}`, { expense: expenseData });
      } else {
        response = await api.post(`/groups/${groupId}/expenses`, { expense: expenseData });
      }

      if (response.status === 200 || response.status === 201) {
        console.log('Despesa salva com sucesso', response.data);
        onFormSubmit();
      } else {
        setError(response.data.errors ? response.data.errors.join(', ') : 'Erro desconhecido ao salvar despesa.');
      }
    } catch (err: any) {
      console.error('Erro ao salvar despesa', err);
      if (err.response && err.response.data && err.response.data.errors) {
        setError(err.response.data.errors.join(', '));
      } else if (err.response && err.response.data && err.response.data.message) {
        setError(err.response.data.message);
      } else {
        setError('Erro ao tentar salvar despesa. Por favor, tente novamente.');
      }
    }
    setLoading(false);
  };

  return (
    <form onSubmit={handleSubmit} className="expense-form">
      <h2>{existingExpense ? 'Editar Despesa' : 'Criar Nova Despesa'}</h2>
      {error && <p className="error-message">{error}</p>}

      <div>
        <label htmlFor="description">Descrição:</label>
        <input
          type="text"
          id="description"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          required
        />
      </div>

      <div>
        <label htmlFor="totalAmount">Valor Total:</label>
        <input
          type="number"
          id="totalAmount"
          value={totalAmount}
          onChange={(e) => setTotalAmount(e.target.value)}
          step="0.01"
          required
        />
      </div>

      <div>
        <label htmlFor="expenseDate">Data da Despesa:</label>
        <input
          type="date"
          id="expenseDate"
          value={expenseDate}
          onChange={(e) => setExpenseDate(e.target.value)}
          required
        />
      </div>

      <div>
        <label htmlFor="currency">Moeda:</label>
        <input
          type="text"
          id="currency"
          value={currency}
          onChange={(e) => setCurrency(e.target.value)}
          maxLength={3}
          required
        />
      </div>

      <div>
        <label>Método de Divisão:</label>
        <select value={splittingMethod} onChange={(e) => setSplittingMethod(e.target.value)}>
          <option value="equally">Dividir Igualmente</option>
          <option value="percentages">Por Porcentagens</option>
          <option value="weights">Por Pesos</option>
          <option value="fixed_amounts">Por Valores Fixos</option>
        </select>
      </div>

      <div className="participants-selection">
        <label>Participantes:</label>
        {groupMembers.map(member => (
          <div key={member.id} className="participant-item">
            <input
              type="checkbox"
              id={`participant-${member.id}`}
              checked={participantsInput[member.id]?.selected || false}
              onChange={(e) => handleParticipantSelection(member.id, e.target.checked)}
            />
            <label htmlFor={`participant-${member.id}`}>{member.name}</label>
            
            {participantsInput[member.id]?.selected && splittingMethod !== 'equally' && (
              <input
                type="number"
                step="0.01"
                placeholder={
                  splittingMethod === 'percentages' ? '%' :
                  splittingMethod === 'weights' ? 'Peso' :
                  'Valor Fixo'
                }
                value={participantsInput[member.id]?.[splittingMethod === 'percentages' ? 'percentage' : splittingMethod === 'weights' ? 'weight' : 'fixed_amount'] || ''}
                onChange={(e) => handleSplittingParamChange(member.id, splittingMethod === 'percentages' ? 'percentage' : splittingMethod === 'weights' ? 'weight' : 'fixed_amount', e.target.value)}
                required={splittingMethod !== 'equally'}
                className="splitting-param-input"
              />
            )}
          </div>
        ))}
      </div>
      
      {splittingMethod !== 'equally' && (parseFloat(calculateRemainingAmount()) !== 0 && !isNaN(parseFloat(calculateRemainingAmount()))) && (
        <p className="remaining-amount">Valor Restante para alocar: {calculateRemainingAmount()} {currency}</p>
      )}

      <div className="form-actions">
        <button type="submit" disabled={loading}>
          {loading ? 'Salvando...' : 'Salvar Despesa'}
        </button>
        <button type="button" onClick={onCancel} disabled={loading}>
          Cancelar
        </button>
      </div>
    </form>
  );
};

export default ExpenseForm;
