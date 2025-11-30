// fullstack_app/client/src/components/payments/PaymentList.tsx
import React from 'react';

interface User {
  id: number;
  name: string;
}

interface Payment {
  id: number;
  amount: string;
  payer: User;
  receiver: User;
  payment_date: string;
  currency: string;
}

interface PaymentListProps {
  payments: Payment[];
  onEditPayment: (payment: Payment) => void;
  onDeletePayment: (paymentId: number) => void;
}

const PaymentList: React.FC<PaymentListProps> = ({ payments, onEditPayment, onDeletePayment }) => {
  if (!payments || payments.length === 0) {
    return <p>Nenhum pagamento registrado neste grupo ainda.</p>;
  }

  return (
    <div className="payment-list">
      <h3>Pagamentos do Grupo</h3>
      {payments.map(payment => (
        <div key={payment.id} className="payment-item">
          <div className="payment-info">
            <h4>Pagamento de {payment.payer.name} para {payment.receiver.name}</h4>
            <p>Valor: {payment.amount} {payment.currency}</p>
            <p>Data: {new Date(payment.payment_date).toLocaleDateString()}</p>
          </div>
          <div className="payment-actions">
            <button onClick={() => onEditPayment(payment)}>Editar</button>
            <button onClick={() => onDeletePayment(payment.id)}>Excluir</button>
          </div>
        </div>
      ))}
    </div>
  );
};

export default PaymentList;
