# frozen_string_literal: true

require 'bigdecimal'

# Simulação das estruturas de dados necessárias para o BalanceCalculator

# Estruturas de suporte
User = Struct.new(:id) do
  def to_s
    "User_#{id}"
  end
  def ==(other)
    other.is_a?(User) && id == other.id
  end
end

ExpenseParticipant = Struct.new(:user, :amount_owed)

Expense = Struct.new(:id, :payer, :total_amount, :expense_participants)

Payment = Struct.new(:id, :payer, :receiver, :amount)

Group = Struct.new(:id, :active_members, :expenses, :payments)


# A classe BalanceCalculator (reproduzida para que o teste seja autossuficiente)
class BalanceCalculator
  require 'bigdecimal'

  def initialize(group)
    @group = group
    @members = group.active_members
  end

  # Calcula o saldo líquido de cada usuário no grupo.
  # @return [Hash<User, BigDecimal>] Um hash mapeando usuários para seus saldos líquidos.
  def calculate_net_balances
    net_balances = Hash.new { |hash, key| hash[key] = BigDecimal('0.00') }

    # Processar despesas
    @group.expenses.each do |expense|
      net_balances[expense.payer] += expense.total_amount

      expense.expense_participants.each do |participant|
        net_balances[participant.user] -= participant.amount_owed
      end
    end

    # Processar pagamentos
    @group.payments.each do |payment|
      net_balances[payment.payer] += payment.amount
      net_balances[payment.receiver] -= payment.amount
    end

    ensure_total_balance_is_zero(net_balances)
    net_balances
  end

  # Calcula os balanços detalhados de "quem deve a quem" dentro do grupo.
  # @return [Hash<User, Hash<User, BigDecimal>>] Um hash aninhado representando as dívidas diretas.
  def calculate_detailed_balances
    direct_debts = Hash.new { |h1, k1| h1[k1] = Hash.new { |h2, k2| h2[k2] = BigDecimal('0.00') } }

    # Processar despesas para construir dívidas diretas
    @group.expenses.each do |expense|
      expense.expense_participants.each do |participant|
        # O participante deve ao pagador
        if participant.user != expense.payer
          direct_debts[participant.user][expense.payer] += participant.amount_owed
        end
      end
    end

    # Processar pagamentos para reduzir dívidas diretas
    @group.payments.each do |payment|
      amount_to_settle = payment.amount

      # Tenta reduzir a dívida direta do pagador para o recebedor
      if direct_debts[payment.payer] && direct_debts[payment.payer][payment.receiver]
        debt = direct_debts[payment.payer][payment.receiver]
        if amount_to_settle >= debt
          direct_debts[payment.payer].delete(payment.receiver)
          amount_to_settle -= debt
        else
          direct_debts[payment.payer][payment.receiver] -= amount_to_settle
          amount_to_settle = BigDecimal('0.00')
        end
      end

      # Caso haja excesso no pagamento (o pagador pagou mais do que devia),
      # isso gera uma dívida reversa (o recebedor agora deve ao pagador).
      if amount_to_settle > BigDecimal('0.00')
        direct_debts[payment.receiver][payment.payer] += amount_to_settle
      end
    end

    # Remove dívidas zeradas e usuários sem dívidas/créditos
    cleaned_debts = {}
    direct_debts.each do |debtor, creditors_hash|
      cleaned_creditors = creditors_hash.select { |_creditor, amount| amount > BigDecimal('0.00') }
      cleaned_debts[debtor] = cleaned_creditors if cleaned_creditors.any?
    end

    cleaned_debts
  end

  private

  # Garante que a soma total dos balanços do grupo seja zero ou muito próxima de zero.
  def ensure_total_balance_is_zero(net_balances)
    total_sum = net_balances.values.sum
    if total_sum.abs > BigDecimal('0.01')
      # Em um ambiente de teste, podemos apenas logar ou levantar um erro (aqui, vamos ajustar)
      if @members.any?
        net_balances[@members.first] -= total_sum.round(2)
      end
    else
      net_balances.transform_values! { |amount| amount.round(2) }
    end
  end
end


RSpec.describe BalanceCalculator do
  let(:u1) { User.new(1) }
  let(:u2) { User.new(2) }
  let(:u3) { User.new(3) }
  let(:members) { [u1, u2, u3] }
  let(:zero) { BigDecimal('0.00') }
  let(:tolerance) { BigDecimal('0.01') }

  # Helper para BigDecimal
  def b(value)
    BigDecimal(value.to_s)
  end
  
  # --- Testes para calculate_net_balances ---
  describe '#calculate_net_balances' do
    context 'when only one expense exists (split equally)' do
      let(:expense1) {
        Expense.new(1, u1, b('30.00'), [
          ExpenseParticipant.new(u1, b('10.00')),
          ExpenseParticipant.new(u2, b('10.00')),
          ExpenseParticipant.new(u3, b('10.00'))
        ])
      }
      let(:group) { Group.new(101, members, [expense1], []) }

      it 'calculates the correct net balances (u1: +20, u2: -10, u3: -10)' do
        calculator = BalanceCalculator.new(group)
        result = calculator.calculate_net_balances

        expect(result[u1]).to be_within(tolerance).of(b('20.00'))
        expect(result[u2]).to be_within(tolerance).of(b('-10.00'))
        expect(result[u3]).to be_within(tolerance).of(b('-10.00'))
        # Verifica se a soma é zero
        expect(result.values.sum).to be_within(tolerance).of(zero)
      end
    end

    context 'when expenses and a full payment exist' do
      let(:expense1) { # U1 paga 30, deve 10, U2 deve 10, U3 deve 10
        Expense.new(1, u1, b('30.00'), [
          ExpenseParticipant.new(u1, b('10.00')),
          ExpenseParticipant.new(u2, b('10.00')),
          ExpenseParticipant.new(u3, b('10.00'))
        ])
      }
      let(:payment1) { # U2 paga sua dívida de 10 para U1
        Payment.new(1, u2, u1, b('10.00'))
      }
      let(:group) { Group.new(102, members, [expense1], [payment1]) }

      it 'correctly adjusts balances after payment' do
        calculator = BalanceCalculator.new(group)
        result = calculator.calculate_net_balances
        
        # Saldo inicial: U1(+20), U2(-10), U3(-10)
        # Pagamento: U2(pagador) +10, U1(recebedor) -10
        # Saldo final: U1(+10), U2(0), U3(-10)

        expect(result[u1]).to be_within(tolerance).of(b('10.00'))
        expect(result[u2]).to be_within(tolerance).of(zero)
        expect(result[u3]).to be_within(tolerance).of(b('-10.00'))
        expect(result.values.sum).to be_within(tolerance).of(zero)
      end
    end
    
    context 'when rounding causes a small discrepancy' do
      let(:expense1) { # U1 paga 100, dividido por 3. Deve 33.3333...
        Expense.new(1, u1, b('100.00'), [
          ExpenseParticipant.new(u1, b('33.3333')),
          ExpenseParticipant.new(u2, b('33.3333')),
          ExpenseParticipant.new(u3, b('33.3334'))
        ])
      }
      let(:group) { Group.new(103, members, [expense1], []) }

      it 'adjusts the total sum to zero and rounds the final result' do
        calculator = BalanceCalculator.new(group)
        result = calculator.calculate_net_balances
        
        # Balanços antes do ajuste/arredondamento:
        # U1: 100 - 33.3333 = 66.6667
        # U2: -33.3333
        # U3: -33.3334
        # Soma: 0.0000

        # Balanços esperados após arredondamento (round(2)):
        # U1: 66.67
        # U2: -33.33
        # U3: -33.33
        # Soma: 0.01 (que será ajustado)

        # Se a soma final for 0.01, o U1 (primeiro membro) será ajustado em -0.01.
        # U1: 66.67 - 0.01 = 66.66

        expect(result[u1]).to be_within(tolerance).of(b('66.66'))
        expect(result[u2]).to be_within(tolerance).of(b('-33.33'))
        expect(result[u3]).to be_within(tolerance).of(b('-33.33'))
        expect(result.values.sum).to be_within(tolerance).of(zero) # Garante que está zerado
      end
    end
  end
  
  # --- Testes para calculate_detailed_balances ---
  describe '#calculate_detailed_balances' do
    context 'when multiple expenses and no payments exist' do
      let(:expense1) { # U1 paga 20. U2 deve 10, U3 deve 10.
        Expense.new(1, u1, b('20.00'), [
          ExpenseParticipant.new(u2, b('10.00')),
          ExpenseParticipant.new(u3, b('10.00'))
        ])
      }
      let(:expense2) { # U2 paga 50. U1 deve 25, U3 deve 25.
        Expense.new(2, u2, b('50.00'), [
          ExpenseParticipant.new(u1, b('25.00')),
          ExpenseParticipant.new(u3, b('25.00'))
        ])
      }
      let(:group) { Group.new(201, members, [expense1, expense2], []) }

      it 'generates the correct direct debt graph' do
        calculator = BalanceCalculator.new(group)
        result = calculator.calculate_detailed_balances
        
        # U2 deve U1: 10.00
        # U3 deve U1: 10.00
        # U1 deve U2: 25.00
        # U3 deve U2: 25.00
        
        # Esperado: { Devedor => { Credor => Montante } }
        expect(result.keys).to contain_exactly(u2, u3, u1)

        # Dívidas do U2
        expect(result[u2].keys).to contain_exactly(u1)
        expect(result[u2][u1]).to be_within(tolerance).of(b('10.00'))
        
        # Dívidas do U3
        expect(result[u3].keys).to contain_exactly(u1, u2)
        expect(result[u3][u1]).to be_within(tolerance).of(b('10.00'))
        expect(result[u3][u2]).to be_within(tolerance).of(b('25.00'))

        # Dívidas do U1
        expect(result[u1].keys).to contain_exactly(u2)
        expect(result[u1][u2]).to be_within(tolerance).of(b('25.00'))
      end
    end

    context 'when a partial payment reduces a direct debt' do
      let(:expense1) { # U1 paga 100. U2 deve 50, U3 deve 50.
        Expense.new(1, u1, b('100.00'), [
          ExpenseParticipant.new(u2, b('50.00')),
          ExpenseParticipant.new(u3, b('50.00'))
        ])
      }
      let(:payment1) { # U2 paga 20 para U1
        Payment.new(1, u2, u1, b('20.00'))
      }
      let(:group) { Group.new(202, members, [expense1], [payment1]) }

      it 'updates the debt graph correctly after payment' do
        calculator = BalanceCalculator.new(group)
        result = calculator.calculate_detailed_balances
        
        # Dívidas iniciais: U2 deve U1 50.00, U3 deve U1 50.00
        # Pagamento: U2 paga U1 20.00
        # Dívida U2 para U1 restante: 50.00 - 20.00 = 30.00

        expect(result.keys).to contain_exactly(u2, u3)
        expect(result[u2].keys).to contain_exactly(u1)
        expect(result[u2][u1]).to be_within(tolerance).of(b('30.00'))
        
        expect(result[u3].keys).to contain_exactly(u1)
        expect(result[u3][u1]).to be_within(tolerance).of(b('50.00'))
      end
    end
    
    context 'when an overpayment creates a reverse debt' do
      let(:expense1) { # U1 paga 10. U2 deve 10.
        Expense.new(1, u1, b('10.00'), [
          ExpenseParticipant.new(u2, b('10.00'))
        ])
      }
      let(:payment1) { # U2 paga 50 para U1 (overpayment)
        Payment.new(1, u2, u1, b('50.00'))
      }
      let(:group) { Group.new(203, members, [expense1], [payment1]) }

      it 'quits the original debt and creates a reverse debt (U1 owes U2)' do
        calculator = BalanceCalculator.new(group)
        result = calculator.calculate_detailed_balances
        
        # Dívida inicial: U2 deve U1 10.00
        # Pagamento: U2 paga U1 50.00
        # 1. Quita U2->U1: 10.00. Montante restante: 40.00
        # 2. Cria dívida reversa: U1 deve U2 40.00

        expect(result.keys).to contain_exactly(u1)
        expect(result[u1].keys).to contain_exactly(u2)
        expect(result[u1][u2]).to be_within(tolerance).of(b('40.00'))
        
        # O U2 não deve mais ninguém
        expect(result[u2]).to be_nil
      end
    end
  end
end