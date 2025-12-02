# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BalanceCalculator Integration', type: :integration do
  let!(:group) { create(:group) }
  let!(:user_a) { create(:user) }
  let!(:user_b) { create(:user) }
  let!(:user_c) { create(:user) }

  let!(:membership_a) { create(:group_membership, group: group, user: user_a, status: 'active') }
  let!(:membership_b) { create(:group_membership, group: group, user: user_b, status: 'active') }
  let!(:membership_c) { create(:group_membership, group: group, user: user_c, status: 'active') }

  describe '#calculate_net_balances' do
    it 'calculates net balances after expenses and payments' do
      # User A pays 100 for a shared expense
      expense = create(:expense, group: group, payer: user_a, total_amount: BigDecimal('100.00'))
      create(:expense_participant, expense: expense, user: user_a, amount_owed: BigDecimal('33.34'))
      create(:expense_participant, expense: expense, user: user_b, amount_owed: BigDecimal('33.33'))
      create(:expense_participant, expense: expense, user: user_c, amount_owed: BigDecimal('33.33'))

      # User B pays 30 to User A
      payment = create(:payment, group: group, payer: user_b, receiver: user_a, amount: BigDecimal('30.00'))

      calculator = BalanceCalculator.new(group)
      net_balances = calculator.calculate_net_balances

      # Expected:
      # User A: +100 (paid) - 33.34 (owed) + 30 (received) = +96.66
      # User B: -33.33 (owed) - 30 (paid) = -63.33
      # User C: -33.33 (owed) = -33.33
      # Sum should be ~0 (allowing for rounding)
      expect(net_balances[user_a]).to be_within(BigDecimal('0.01')).of(BigDecimal('96.66'))
      expect(net_balances[user_b]).to be_within(BigDecimal('0.01')).of(BigDecimal('-63.33'))
      expect(net_balances[user_c]).to be_within(BigDecimal('0.01')).of(BigDecimal('-33.33'))
      expect(net_balances.values.sum).to be_within(BigDecimal('0.01')).of(BigDecimal('0.00'))
    end

    it 'handles multiple expenses correctly' do
      # First expense: User A pays 60
      expense1 = create(:expense, group: group, payer: user_a, total_amount: BigDecimal('60.00'))
      create(:expense_participant, expense: expense1, user: user_a, amount_owed: BigDecimal('20.00'))
      create(:expense_participant, expense: expense1, user: user_b, amount_owed: BigDecimal('20.00'))
      create(:expense_participant, expense: expense1, user: user_c, amount_owed: BigDecimal('20.00'))

      # Second expense: User B pays 90
      expense2 = create(:expense, group: group, payer: user_b, total_amount: BigDecimal('90.00'))
      create(:expense_participant, expense: expense2, user: user_a, amount_owed: BigDecimal('30.00'))
      create(:expense_participant, expense: expense2, user: user_b, amount_owed: BigDecimal('30.00'))
      create(:expense_participant, expense: expense2, user: user_c, amount_owed: BigDecimal('30.00'))

      calculator = BalanceCalculator.new(group)
      net_balances = calculator.calculate_net_balances

      # Expected:
      # User A: +60 - 20 - 30 = +10
      # User B: +90 - 20 - 30 = +40
      # User C: -20 - 30 = -50
      expect(net_balances[user_a]).to be_within(BigDecimal('0.01')).of(BigDecimal('10.00'))
      expect(net_balances[user_b]).to be_within(BigDecimal('0.01')).of(BigDecimal('40.00'))
      expect(net_balances[user_c]).to be_within(BigDecimal('0.01')).of(BigDecimal('-50.00'))
      expect(net_balances.values.sum).to be_within(BigDecimal('0.01')).of(BigDecimal('0.00'))
    end
  end

  describe '#calculate_detailed_balances' do
    it 'creates direct debt relationships' do
      # User A pays for everyone
      expense = create(:expense, group: group, payer: user_a, total_amount: BigDecimal('90.00'))
      create(:expense_participant, expense: expense, user: user_b, amount_owed: BigDecimal('30.00'))
      create(:expense_participant, expense: expense, user: user_c, amount_owed: BigDecimal('30.00'))
      # User A is also a participant but doesn't create debt to self

      calculator = BalanceCalculator.new(group)
      detailed_balances = calculator.calculate_detailed_balances

      expect(detailed_balances[user_b][user_a]).to eq(BigDecimal('30.00'))
      expect(detailed_balances[user_c][user_a]).to eq(BigDecimal('30.00'))
      expect(detailed_balances[user_a]).to be_nil # No debts from payer to self
    end

    it 'reduces debts with payments' do
      # Setup initial debt
      expense = create(:expense, group: group, payer: user_a, total_amount: BigDecimal('60.00'))
      create(:expense_participant, expense: expense, user: user_b, amount_owed: BigDecimal('20.00'))

      # User B pays 15 to User A
      payment = create(:payment, group: group, payer: user_b, receiver: user_a, amount: BigDecimal('15.00'))

      calculator = BalanceCalculator.new(group)
      detailed_balances = calculator.calculate_detailed_balances

      # Original debt was 20, payment of 15 reduces it to 5
      expect(detailed_balances[user_b][user_a]).to eq(BigDecimal('5.00'))
    end

    it 'creates reverse debt when overpayment occurs' do
      # User A pays 30, but User B only owes 20
      expense = create(:expense, group: group, payer: user_a, total_amount: BigDecimal('30.00'))
      create(:expense_participant, expense: expense, user: user_b, amount_owed: BigDecimal('20.00'))

      # User B pays 30 to User A (10 more than owed)
      payment = create(:payment, group: group, payer: user_b, receiver: user_a, amount: BigDecimal('30.00'))

      calculator = BalanceCalculator.new(group)
      detailed_balances = calculator.calculate_detailed_balances

      # Original debt of 20 is paid, extra 10 creates reverse debt
      expect(detailed_balances[user_a][user_b]).to eq(BigDecimal('10.00'))
      expect(detailed_balances[user_b]).to be_nil # Original debt cleared, so user_b entry removed
    end
  end
end
