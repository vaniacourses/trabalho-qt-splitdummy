# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BalanceAggregator Integration', type: :integration do
  let!(:group) { create(:group) }
  let!(:user_a) { create(:user) }
  let!(:user_b) { create(:user) }
  let!(:user_c) { create(:user) }

  let!(:membership_a) { create(:group_membership, group: group, user: user_a, status: 'active') }
  let!(:membership_b) { create(:group_membership, group: group, user: user_b, status: 'active') }
  let!(:membership_c) { create(:group_membership, group: group, user: user_c, status: 'active') }

  describe '#aggregate_balances' do
    it 'aggregates balances and builds simplified debt graph' do
      # Setup: User A pays 100, split equally
      expense = create(:expense, group: group, payer: user_a, total_amount: BigDecimal('100.00'))
      create(:expense_participant, expense: expense, user: user_a, amount_owed: BigDecimal('33.34'))
      create(:expense_participant, expense: expense, user: user_b, amount_owed: BigDecimal('33.33'))
      create(:expense_participant, expense: expense, user: user_c, amount_owed: BigDecimal('33.33'))

      calculator = BalanceCalculator.new(group)
      net_balances = calculator.calculate_net_balances
      detailed_balances = calculator.calculate_detailed_balances

      aggregator = BalanceAggregator.new(net_balances, detailed_balances)
      simplified_graph = aggregator.aggregate_balances

      # Should create simplified debt relationships
      # User B and C owe User A (net debtors to net creditors)
      expect(simplified_graph).to have_key(user_b)
      expect(simplified_graph).to have_key(user_c)
      expect(simplified_graph[user_b]).to have_key(user_a)
      expect(simplified_graph[user_c]).to have_key(user_a)

      # Verify amounts are reasonable (within rounding tolerance)
      expect(simplified_graph[user_b][user_a]).to be > BigDecimal('0')
      expect(simplified_graph[user_c][user_a]).to be > BigDecimal('0')
    end

    it 'handles multiple debtors and creditors' do
      # Complex scenario with multiple expenses
      # Expense 1: User A pays 90
      expense1 = create(:expense, group: group, payer: user_a, total_amount: BigDecimal('90.00'))
      create(:expense_participant, expense: expense1, user: user_b, amount_owed: BigDecimal('30.00'))
      create(:expense_participant, expense: expense1, user: user_c, amount_owed: BigDecimal('30.00'))

      # Expense 2: User B pays 60
      expense2 = create(:expense, group: group, payer: user_b, total_amount: BigDecimal('60.00'))
      create(:expense_participant, expense: expense2, user: user_a, amount_owed: BigDecimal('20.00'))
      create(:expense_participant, expense: expense2, user: user_c, amount_owed: BigDecimal('20.00'))

      calculator = BalanceCalculator.new(group)
      net_balances = calculator.calculate_net_balances
      detailed_balances = calculator.calculate_detailed_balances

      aggregator = BalanceAggregator.new(net_balances, detailed_balances)
      simplified_graph = aggregator.aggregate_balances

      # Should create optimized debt relationships
      # Based on net balances, User C should be the main debtor
      expect(simplified_graph.keys).to include(user_c)
      simplified_graph[user_c].keys.each do |creditor|
        expect([user_a, user_b]).to include(creditor)
      end
    end

    it 'validates overall balance and adjusts small discrepancies' do
      # Create a scenario with small rounding discrepancy
      expense = create(:expense, group: group, payer: user_a, total_amount: BigDecimal('100.01'))
      create(:expense_participant, expense: expense, user: user_a, amount_owed: BigDecimal('33.34'))
      create(:expense_participant, expense: expense, user: user_b, amount_owed: BigDecimal('33.33'))
      create(:expense_participant, expense: expense, user: user_c, amount_owed: BigDecimal('33.34'))

      calculator = BalanceCalculator.new(group)
      net_balances = calculator.calculate_net_balances
      detailed_balances = calculator.calculate_detailed_balances

      # This should not raise an error despite small rounding differences
      expect {
        aggregator = BalanceAggregator.new(net_balances, detailed_balances)
        aggregator.aggregate_balances
      }.not_to raise_error
    end

    it 'raises error for large balance inconsistencies' do
      # Manually create inconsistent balances to test error handling
      net_balances = {
        user_a => BigDecimal('100.00'),
        user_b => BigDecimal('50.00'),
        user_c => BigDecimal('0.00')
      }
      detailed_balances = {}

      # This should raise an error due to non-zero sum
      expect {
        aggregator = BalanceAggregator.new(net_balances, detailed_balances)
        aggregator.aggregate_balances
      }.to raise_error(RuntimeError, /Inconsistência grave no balanço/)
    end
  end
end
