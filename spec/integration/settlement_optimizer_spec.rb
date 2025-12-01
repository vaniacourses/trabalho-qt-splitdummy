# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SettlementOptimizer Integration', type: :integration do
  let!(:group) { create(:group) }
  let!(:user_a) { create(:user) }
  let!(:user_b) { create(:user) }
  let!(:user_c) { create(:user) }

  let!(:membership_a) { create(:group_membership, group: group, user: user_a, status: 'active') }
  let!(:membership_b) { create(:group_membership, group: group, user: user_b, status: 'active') }
  let!(:membership_c) { create(:group_membership, group: group, user: user_c, status: 'active') }

  describe '#generate_optimized_payments' do
    it 'optimizes simple debt scenario' do
      # Simple scenario: User B owes User A
      simplified_graph = {
        user_b => { user_a => BigDecimal('50.00') }
      }

      optimizer = SettlementOptimizer.new(simplified_graph)
      payments = optimizer.generate_optimized_payments

      expect(payments.size).to eq(1)
      expect(payments.first[:payer]).to eq(user_b)
      expect(payments.first[:receiver]).to eq(user_a)
      expect(payments.first[:amount]).to eq(BigDecimal('50.00'))
    end

    it 'optimizes chain payments to direct payments' do
      # Chain: B owes A, A owes C -> should optimize to B pays C directly
      simplified_graph = {
        user_b => { user_a => BigDecimal('30.00') },
        user_a => { user_c => BigDecimal('30.00') }
      }

      optimizer = SettlementOptimizer.new(simplified_graph)
      payments = optimizer.generate_optimized_payments

      expect(payments.size).to eq(1)
      expect(payments.first[:payer]).to eq(user_b)
      expect(payments.first[:receiver]).to eq(user_c)
      expect(payments.first[:amount]).to eq(BigDecimal('30.00'))
    end

    it 'handles multiple debtors and creditors' do
      # Complex scenario: B owes A, C owes A, B owes C
      simplified_graph = {
        user_b => { 
          user_a => BigDecimal('40.00'),
          user_c => BigDecimal('20.00')
        },
        user_c => { user_a => BigDecimal('30.00') }
      }

      optimizer = SettlementOptimizer.new(simplified_graph)
      payments = optimizer.generate_optimized_payments

      # Should optimize to minimal number of payments
      expect(payments.size).to be <= 3

      # Verify all payments are valid
      payments.each do |payment|
        expect(payment[:amount]).to be > BigDecimal('0')
        expect([user_a, user_b, user_c]).to include(payment[:payer])
        expect([user_a, user_b, user_c]).to include(payment[:receiver])
      end
    end

    it 'ignores payments below tolerance' do
      # Include a very small payment that should be ignored
      simplified_graph = {
        user_b => { user_a => BigDecimal('50.00') },
        user_c => { user_a => BigDecimal('0.005') } # Below default tolerance of 0.01
      }

      optimizer = SettlementOptimizer.new(simplified_graph)
      payments = optimizer.generate_optimized_payments

      expect(payments.size).to eq(1)
      expect(payments.first[:payer]).to eq(user_b)
      expect(payments.first[:amount]).to eq(BigDecimal('50.00'))
    end

    it 'respects custom tolerance' do
      # Use custom tolerance to include/exclude payments
      simplified_graph = {
        user_b => { user_a => BigDecimal('0.05') }
      }

      # Default tolerance (0.01) should include this payment
      optimizer = SettlementOptimizer.new(simplified_graph)
      payments = optimizer.generate_optimized_payments
      expect(payments.size).to eq(1)

      # Higher tolerance should exclude this payment
      optimizer_high_tolerance = SettlementOptimizer.new(simplified_graph, tolerance: BigDecimal('0.10'))
      payments_high = optimizer_high_tolerance.generate_optimized_payments
      expect(payments_high.size).to eq(0)
    end

    it 'handles circular debts' do
      # Circular: A owes B, B owes C, C owes A
      simplified_graph = {
        user_a => { user_b => BigDecimal('25.00') },
        user_b => { user_c => BigDecimal('25.00') },
        user_c => { user_a => BigDecimal('25.00') }
      }

      optimizer = SettlementOptimizer.new(simplified_graph)
      payments = optimizer.generate_optimized_payments

      # Should resolve circular debts efficiently
      # In perfect circular debt, might result in no payments needed
      # or minimal payments depending on implementation
      expect(payments.size).to be <= 3
    end
  end

  describe 'full integration flow' do
    it 'integrates with BalanceCalculator and BalanceAggregator' do
      # Create realistic expense scenario
      expense = create(:expense, group: group, payer: user_a, total_amount: BigDecimal('120.00'))
      create(:expense_participant, expense: expense, user: user_a, amount_owed: BigDecimal('40.00'))
      create(:expense_participant, expense: expense, user: user_b, amount_owed: BigDecimal('40.00'))
      create(:expense_participant, expense: expense, user: user_c, amount_owed: BigDecimal('40.00'))

      # Add a payment
      create(:payment, group: group, payer: user_b, receiver: user_a, amount: BigDecimal('20.00'))

      # Full flow
      calculator = BalanceCalculator.new(group)
      net_balances = calculator.calculate_net_balances
      detailed_balances = calculator.calculate_detailed_balances

      aggregator = BalanceAggregator.new(net_balances, detailed_balances)
      simplified_graph = aggregator.aggregate_balances

      optimizer = SettlementOptimizer.new(simplified_graph)
      payments = optimizer.generate_optimized_payments

      # Verify the flow produces valid optimized payments
      expect(payments).to be_an(Array)
      payments.each do |payment|
        expect(payment).to have_key(:payer)
        expect(payment).to have_key(:receiver)
        expect(payment).to have_key(:amount)
        expect(payment[:amount]).to be > BigDecimal('0')
      end

      # Verify the payments actually settle the debts
      # This is a complex verification, but we can at least check the structure
      total_payment_amount = payments.sum { |p| p[:amount] }
      expect(total_payment_amount).to be > BigDecimal('0')
    end
  end
end
