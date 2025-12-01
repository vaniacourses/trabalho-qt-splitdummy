# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TransactionSimplifier Integration', type: :integration do
  let!(:group) { create(:group) }
  let!(:user_a) { create(:user) }
  let!(:user_b) { create(:user) }
  let!(:user_c) { create(:user) }

  let!(:membership_a) { create(:group_membership, group: group, user: user_a, status: 'active') }
  let!(:membership_b) { create(:group_membership, group: group, user: user_b, status: 'active') }
  let!(:membership_c) { create(:group_membership, group: group, user: user_c, status: 'active') }

  describe '#simplify_transactions' do
    it 'removes direct opposing debts' do
      # A owes B 50, B owes A 30 -> should simplify to A owes B 20
      debt_graph = {
        user_a => { user_b => BigDecimal('50.00') },
        user_b => { user_a => BigDecimal('30.00') }
      }

      simplifier = TransactionSimplifier.new(debt_graph)
      simplified = simplifier.simplify_transactions

      expect(simplified).to have_key(user_a)
      expect(simplified[user_a]).to have_key(user_b)
      expect(simplified[user_a][user_b]).to eq(BigDecimal('20.00'))
      expect(simplified[user_b]).not_to have_key(user_a)
    end

    it 'removes cycles of three or more users' do
      # A owes B 25, B owes C 25, C owes A 25 -> should remove the cycle
      debt_graph = {
        user_a => { user_b => BigDecimal('25.00') },
        user_b => { user_c => BigDecimal('25.00') },
        user_c => { user_a => BigDecimal('25.00') }
      }

      simplifier = TransactionSimplifier.new(debt_graph)
      simplified = simplifier.simplify_transactions

      # In a perfect cycle, all debts should be cancelled out
      expect(simplified).to be_empty
    end

    it 'handles partial cycle removal' do
      # A owes B 30, B owes C 20, C owes A 10
      # Minimum in cycle is 10, so:
      # A owes B becomes 20, B owes C becomes 10, C owes A becomes 0
      debt_graph = {
        user_a => { user_b => BigDecimal('30.00') },
        user_b => { user_c => BigDecimal('20.00') },
        user_c => { user_a => BigDecimal('10.00') }
      }

      simplifier = TransactionSimplifier.new(debt_graph)
      simplified = simplifier.simplify_transactions

      expect(simplified[user_a][user_b]).to eq(BigDecimal('20.00'))
      expect(simplified[user_b][user_c]).to eq(BigDecimal('10.00'))
      expect(simplified[user_c]).not_to have_key(user_a)
    end

    it 'cleans up zero and small debts' do
      debt_graph = {
        user_a => { 
          user_b => BigDecimal('50.00'),
          user_c => BigDecimal('0.005') # Below tolerance
        },
        user_b => { user_a => BigDecimal('0.008') } # Below tolerance
      }

      simplifier = TransactionSimplifier.new(debt_graph)
      simplified = simplifier.simplify_transactions

      expect(simplified[user_a]).to have_key(user_b)
      expect(simplified[user_a]).not_to have_key(user_c)
      expect(simplified[user_b]).to be_empty # Should be cleaned up
    end

    it 'handles complex multi-user scenarios' do
      # Complex scenario with multiple relationships
      debt_graph = {
        user_a => { 
          user_b => BigDecimal('40.00'),
          user_c => BigDecimal('15.00')
        },
        user_b => { 
          user_a => BigDecimal('20.00'),
          user_c => BigDecimal('30.00')
        },
        user_c => { 
          user_a => BigDecimal('10.00')
        }
      }

      simplifier = TransactionSimplifier.new(debt_graph)
      simplified = simplifier.simplify_transactions

      # Should simplify opposing debts and remove cycles
      # A owes B 40, B owes A 20 -> A owes B 20
      expect(simplified[user_a][user_b]).to eq(BigDecimal('20.00'))
      expect(simplified[user_b]).not_to have_key(user_a)

      # Other relationships should be preserved but optimized
      expect(simplified.keys).to include(user_a, user_b, user_c)
    end

    it 'respects custom tolerance' do
      debt_graph = {
        user_a => { user_b => BigDecimal('0.05') }
      }

      # Default tolerance should keep this payment
      simplifier_default = TransactionSimplifier.new(debt_graph)
      simplified_default = simplifier_default.simplify_transactions
      expect(simplified_default[user_a][user_b]).to eq(BigDecimal('0.05'))

      # Higher tolerance should remove this payment
      simplifier_high = TransactionSimplifier.new(debt_graph, tolerance: BigDecimal('0.10'))
      simplified_high = simplifier_high.simplify_transactions
      expect(simplified_high).to be_empty
    end

    it 'does not modify original graph' do
      original_graph = {
        user_a => { user_b => BigDecimal('50.00') },
        user_b => { user_a => BigDecimal('30.00') }
      }

      simplifier = TransactionSimplifier.new(original_graph)
      simplified = simplifier.simplify_transactions

      # Original should be unchanged
      expect(original_graph[user_a][user_b]).to eq(BigDecimal('50.00'))
      expect(original_graph[user_b][user_a]).to eq(BigDecimal('30.00'))

      # Simplified should be different
      expect(simplified[user_a][user_b]).to eq(BigDecimal('20.00'))
      expect(simplified[user_b]).not_to have_key(user_a)
    end
  end

  describe 'integration with other services' do
    it 'can work with BalanceCalculator output' do
      # Create a realistic scenario
      expense = create(:expense, group: group, payer: user_a, total_amount: BigDecimal('90.00'))
      create(:expense_participant, expense: expense, user: user_b, amount_owed: BigDecimal('30.00'))
      create(:expense_participant, expense: expense, user: user_c, amount_owed: BigDecimal('30.00'))

      # Add opposing payment
      create(:payment, group: group, payer: user_b, receiver: user_a, amount: BigDecimal('20.00'))

      calculator = BalanceCalculator.new(group)
      detailed_balances = calculator.calculate_detailed_balances

      simplifier = TransactionSimplifier.new(detailed_balances)
      simplified = simplifier.simplify_transactions

      # Should simplify the opposing debts
      expect(simplified).to be_a(Hash)
      if simplified.any?
        simplified.each do |debtor, creditors|
          creditors.each do |creditor, amount|
            expect(amount).to be > BigDecimal('0')
          end
        end
      end
    end
  end
end
