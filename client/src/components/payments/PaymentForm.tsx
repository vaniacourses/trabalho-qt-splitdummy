// fullstack_app/client/src/components/payments/PaymentForm.tsx
import React, { useState, useEffect } from 'react';
import api from '../../services/api';

interface User {
  id: number;
  name: string;
}

interface GroupMember extends User {
  status: string;
}

interface Payment {
  id?: number;
  amount: string;
  payer: User;
  receiver: User;
  group_id: number;
  payment_date: string; // Formato YYYY-MM-DD
  currency: string;
}

interface PaymentFormProps {
  groupId: number;
  groupMembers: GroupMember[]; // Membros do grupo para seleção do recebedor
  currentUser: User; // Usuário logado é o pagador
  existingPayment?: Payment | null;
  onFormSubmit: () => void;
  onCancel: () => void;
}

const PaymentForm: React.FC<PaymentFormProps> = ({ groupId, groupMembers, currentUser, existingPayment, onFormSubmit, onCancel }) => {
  const [amount, setAmount] = useState(existingPayment?.amount || '');
  const [receiverId, setReceiverId] = useState<number | ''>(
    existingPayment?.receiver.id || ''
  );
  const [paymentDate, setPaymentDate] = useState(existingPayment?.payment_date || new Date().toISOString().split('T')[0]);
  const [currency, setCurrency] = useState(existingPayment?.currency || 'BRL');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (existingPayment) {
      console.log('Existing Payment:', existingPayment);
      console.log('Existing Payment Receiver ID:', existingPayment.receiver.id);
      setAmount(existingPayment.amount);
      setReceiverId(existingPayment.receiver.id);
      setPaymentDate(existingPayment.payment_date);
      setCurrency(existingPayment.currency);
    } else {
      setAmount('');
      setReceiverId('');
      setPaymentDate(new Date().toISOString().split('T')[0]);
      setCurrency('BRL');
    }
  }, [existingPayment]);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setLoading(true);
    setError(null);

    try {
      if (!receiverId) {
        setError('Selecione um recebedor.');
        setLoading(false);
        return;
      }

      if (currentUser.id === receiverId) {
        setError('Você não pode fazer um pagamento para si mesmo.');
        setLoading(false);
        return;
      }

      const paymentData = {
        amount: parseFloat(amount).toFixed(2),
        receiver_id: receiverId,
        payment_date: paymentDate,
        currency,
      };

      let response;
      if (existingPayment) {
        response = await api.patch(`/groups/${groupId}/payments/${existingPayment.id}`, { payment: paymentData });
      } else {
        response = await api.post(`/groups/${groupId}/payments`, { payment: paymentData });
      }

      if (response.status === 200 || response.status === 201) {
        console.log('Pagamento salvo com sucesso', response.data);
        onFormSubmit();
      } else {
        setError(response.data.errors ? response.data.errors.join(', ') : 'Erro desconhecido ao salvar pagamento.');
      }
    } catch (err: any) {
      console.error('Erro ao salvar pagamento', err);
      if (err.response && err.response.data && err.response.data.errors) {
        setError(err.response.data.errors.join(', '));
      } else if (err.response && err.response.data && err.response.data.message) {
        setError(err.response.data.message);
      } else {
        setError('Erro ao tentar salvar pagamento. Por favor, tente novamente.');
      }
    }
    setLoading(false);
  };

  const otherGroupMembers = groupMembers.filter(member => member.id !== currentUser.id && member.status === 'active');
  console.log('Other Group Members for select:', otherGroupMembers);
  console.log('Current Receiver ID:', receiverId);

  return (
    <form onSubmit={handleSubmit} className="payment-form">
      <h2>{existingPayment ? 'Editar Pagamento' : 'Registrar Novo Pagamento'}</h2>
      {error && <p className="error-message">{error}</p>}

      <div>
        <label htmlFor="amount">Valor:</label>
        <input
          type="number"
          id="amount"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          step="0.01"
          required
        />
      </div>

      <div>
        <label htmlFor="receiver">Recebedor:</label>
        <select
          id="receiver"
          value={receiverId}
          onChange={(e) => setReceiverId(parseInt(e.target.value))}
          required
        >
          <option value="">Selecione um recebedor</option>
          {otherGroupMembers.map(member => (
            <option key={member.id} value={member.id}>
              {member.name}
            </option>
          ))}
        </select>
      </div>

      <div>
        <label htmlFor="paymentDate">Data do Pagamento:</label>
        <input
          type="date"
          id="paymentDate"
          value={paymentDate}
          onChange={(e) => setPaymentDate(e.target.value)}
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

      <div className="form-actions">
        <button type="submit" disabled={loading}>
          {loading ? 'Salvando...' : 'Salvar Pagamento'}
        </button>
        <button type="button" onClick={onCancel} disabled={loading}>
          Cancelar
        </button>
      </div>
    </form>
  );
};

export default PaymentForm;
