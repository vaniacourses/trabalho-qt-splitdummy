# frozen_string_literal: true

require 'bigdecimal'

# Simulação da classe User para os testes, necessária para o Optimizer
User = Struct.new(:id) do
  def to_s
    "User_#{id}"
  end
  def ==(other)
    other.is_a?(User) && id == other.id
  end
end

# A classe SettlementOptimizer (reproduzida para que o teste seja autossuficiente)
class SettlementOptimizer
  require 'bigdecimal'

  # Inicializa o SettlementOptimizer com o grafo de dívidas simplificado.
  # O grafo deve ser no formato { devedor => { credor => montante } }.
  # @param simplified_debt_graph [Hash<User, Hash<User, BigDecimal>>] Grafo de dívidas.
  # @param tolerance [BigDecimal] Tolerância para considerar um balanço como zero.
  def initialize(simplified_debt_graph, tolerance: BigDecimal('0.01'))
    @simplified_debt_graph = simplified_debt_graph
    @tolerance = tolerance
  end

  # Gera o conjunto mínimo de pagamentos necessários para liquidar todas as dívidas.
  # O algoritmo busca identificar os maiores devedores e maiores credores e criar pagamentos diretos.
  # @return [Array<Hash>] Uma lista de pagamentos sugeridos, cada um com :payer, :receiver, :amount.
  def generate_optimized_payments
    # Inicializa os saldos líquidos a partir do grafo de dívidas para identificar credores e devedores líquidos.
    balances = Hash.new { |h, k| h[k] = BigDecimal('0.00') }

    @simplified_debt_graph.each do |debtor, creditors_hash|
      creditors_hash.each do |creditor, amount|
        balances[debtor] -= amount
        balances[creditor] += amount
      end
    end

    # Separa credores e devedores com base nos saldos líquidos.
    # Filtra usuários com balanço zero ou muito próximo de zero (dentro da tolerância).
    creditors = balances.select { |_user, amount| amount > @tolerance }
                        .sort_by { |_user, amount| -amount } # Maiores credores primeiro
                        .to_h
    debtors = balances.select { |_user, amount| amount < -@tolerance }
                      .sort_by { |_user, amount| amount } # Maiores devedores (negativos) primeiro
                      .to_h

    optimized_payments = []

    # Algoritmo principal de otimização:
    # Enquanto houver devedores e credores
    while debtors.any? && creditors.any?
      debtor, debt_amount_raw = debtors.shift
      creditor, credit_amount_raw = creditors.shift

      debt_amount = debt_amount_raw.abs # Transforma dívida em valor absoluto
      credit_amount = credit_amount_raw

      # Determina o valor do pagamento, que é o mínimo entre a dívida e o crédito.
      payment_amount = [debt_amount, credit_amount].min

      if payment_amount > @tolerance # Apenas adiciona pagamentos significativos
        optimized_payments << {
          payer: debtor,
          receiver: creditor,
          amount: payment_amount.round(2)
        }

        # Atualiza os saldos restantes após o pagamento
        remaining_debt = debt_amount - payment_amount
        remaining_credit = credit_amount - payment_amount

        # Se o devedor ainda deve, o coloca de volta na lista de devedores.
        if remaining_debt > @tolerance
          # Reinsere mantendo a ordem (ou reordena, se necessário para a complexidade)
          insert_into_sorted_hash(debtors, debtor, -remaining_debt)
        end

        # Se o credor ainda tem crédito, o coloca de volta na lista de credores.
        if remaining_credit > @tolerance
          # Reinsere mantendo a ordem (ou reordena, se necessário para a complexidade)
          insert_into_sorted_hash(creditors, creditor, remaining_credit)
        end
      else
        # Se o pagamento for muito pequeno para ser significativo, reinserir quem sobrou
        insert_into_sorted_hash(debtors, debtor, debt_amount_raw) if debt_amount > @tolerance
        insert_into_sorted_hash(creditors, creditor, credit_amount_raw) if credit_amount > @tolerance
      end
    end
    optimized_payments
  end

  private

  # Helper para inserir um usuário em um hash ordenado (mantendo a ordem por valor).
  def insert_into_sorted_hash(hash, user, amount)
    new_entry = { user => amount }

    if amount > BigDecimal('0.00') # Credor (ordenado decrescente)
      # Busca o índice onde o novo amount é maior ou igual para manter a ordem decrescente
      index = hash.keys.bsearch_index { |k| hash[k] <= amount } || hash.size
    else # Devedor (ordenado crescente, já que os valores são negativos)
      # Busca o índice onde o novo amount é menor ou igual para manter a ordem crescente (mais negativo primeiro)
      index = hash.keys.bsearch_index { |k| hash[k] >= amount } || hash.size
    end

    # Converte o hash para um array de pares, insere e converte de volta para hash
    arr = hash.to_a
    arr.insert(index, new_entry.first)
    hash.replace(arr.to_h)
  end
end

RSpec.describe SettlementOptimizer do
  let(:u1) { User.new(1) }
  let(:u2) { User.new(2) }
  let(:u3) { User.new(3) }
  let(:u4) { User.new(4) }
  let(:u5) { User.new(5) }
  let(:tolerance) { BigDecimal('0.01') }

  # Helper para comparar BigDecimal
  def b(value)
    BigDecimal(value.to_s)
  end

  # Helper para normalizar o resultado para comparação
  def normalize_payments(payments)
    payments.map do |p|
      { payer: p[:payer], receiver: p[:receiver], amount: p[:amount].round(2) }
    end
  end
  
  # Testes para cenários de otimização de liquidação
  describe '#generate_optimized_payments' do
    
    # Cenário 1: Simplificação de cadeia de dívidas (Chain Debt A -> B -> C)
    # U3 deve U2 100, U2 deve U1 100. Resultado otimizado: U3 deve U1 100.
    context 'when a simple debt chain can be optimized' do
      let(:simplified_debt_graph) {
        {
          u3 => { u2 => b('100.00') },
          u2 => { u1 => b('100.00') }
        }
      }

      it 'returns a single payment from the net debtor (U3) to the net creditor (U1)' do
        optimizer = SettlementOptimizer.new(simplified_debt_graph)
        result = optimizer.generate_optimized_payments

        expected_payments = [
          { payer: u3, receiver: u1, amount: b('100.00') }
        ]

        expect(normalize_payments(result)).to contain_exactly(*normalize_payments(expected_payments))
      end
    end
    
    # Cenário 2: Ciclo de dívidas (Cycle A -> B -> C -> A)
    # O grafo tem transações, mas os saldos líquidos são zero para todos.
    context 'when a debt cycle results in zero net balance' do
      let(:simplified_debt_graph) {
        {
          u1 => { u2 => b('50.00') },
          u2 => { u3 => b('50.00') },
          u3 => { u1 => b('50.00') }
        }
      }

      it 'returns an empty list of payments' do
        optimizer = SettlementOptimizer.new(simplified_debt_graph)
        result = optimizer.generate_optimized_payments

        expect(result).to be_empty
      end
    end
    
    # Cenário 3: Múltiplos Devedores, Múltiplos Credores (Teste Complexo)
    context 'when multiple debtors pay multiple creditors optimally' do
      # Saldos líquidos calculados a partir do grafo:
      # U1: +100 (from U4) - 50 (to U2) = +50 (Creditor)
      # U2: +50 (from U1) - 100 (to U3) = -50 (Debtor)
      # U3: +100 (from U2) - 80 (to U4) = +20 (Creditor)
      # U4: +80 (from U3) - 100 (to U1) = -20 (Debtor)
      # Total: +50 - 50 + 20 - 20 = 0.00
      
      let(:simplified_debt_graph) {
        {
          u1 => { u2 => b('50.00') },
          u2 => { u3 => b('100.00') },
          u3 => { u4 => b('80.00') },
          u4 => { u1 => b('100.00') }
        }
      }

      # Devedores: U2 (50), U4 (20). Total 70.
      # Credores: U1 (50), U3 (20). Total 70.
      # Otimização (Maiores para Maiores):
      # 1. U2 (Debtor 50) paga U1 (Creditor 50). Pagamento: 50.
      #    - U2 restante: 0. U1 restante: 0.
      # 2. U4 (Debtor 20) paga U3 (Creditor 20). Pagamento: 20.
      #    - U4 restante: 0. U3 restante: 0.
      
      it 'generates the minimum number of transactions (U2 -> U1, U4 -> U3)' do
        optimizer = SettlementOptimizer.new(simplified_debt_graph)
        result = optimizer.generate_optimized_payments

        expected_payments = [
          { payer: u2, receiver: u1, amount: b('50.00') },
          { payer: u4, receiver: u3, amount: b('20.00') }
        ]

        expect(normalize_payments(result)).to contain_exactly(*normalize_payments(expected_payments))
      end
    end
    
    # Cenário 4: Distribuição de um devedor para vários credores (U5 paga todos)
    context 'when one large debtor pays multiple creditors' do
      # Saldos líquidos: U1, U2, U3, U4 (+25 cada), U5 (-100). Total: 0.
      let(:simplified_debt_graph) {
        {
          u5 => { u1 => b('25.00'), u2 => b('25.00'), u3 => b('25.00'), u4 => b('25.00') }
        }
      }

      it 'generates a separate payment for each creditor' do
        optimizer = SettlementOptimizer.new(simplified_debt_graph)
        result = optimizer.generate_optimized_payments

        expected_payments = [
          { payer: u5, receiver: u1, amount: b('25.00') },
          { payer: u5, receiver: u2, amount: b('25.00') },
          { payer: u5, receiver: u3, amount: b('25.00') },
          { payer: u5, receiver: u4, amount: b('25.00') }
        ]
        
        # O otimizador pode gerar em ordem diferente dependendo da ordem interna de U1-U4,
        # mas a contagem e o conteúdo devem ser exatos.
        expect(normalize_payments(result)).to contain_exactly(*normalize_payments(expected_payments))
      end
    end

    # Cenário 5: Tratamento de valores próximos de zero (Tolerance)
    context 'when small amounts are within tolerance' do
      # Dívida: U1 (-100.0001) para U2 (+100.0001). Total: 0.0002.
      let(:net_balances) { { u1 => b('-100.0001'), u2 => b('100.0001') } }
      let(:simplified_debt_graph) { { u1 => { u2 => b('100.0001') } } } # Não é um grafo de balanços líquidos, mas sim a transação.

      it 'calculates the full payment and rounds the final amount' do
        optimizer = SettlementOptimizer.new(simplified_debt_graph)
        result = optimizer.generate_optimized_payments

        # O payment_amount será 100.0001 e será arredondado para 100.00 no output.
        expect(result.size).to eq(1)
        expect(result.first[:payer]).to eq(u1)
        expect(result.first[:receiver]).to eq(u2)
        expect(result.first[:amount]).to eq(b('100.00'))
      end
    end
  end
end