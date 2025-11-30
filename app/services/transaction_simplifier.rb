# fullstack_app/app/services/transaction_simplifier.rb
require 'bigdecimal'

class TransactionSimplifier
  # Inicializa o TransactionSimplifier com um grafo de dívidas detalhado ou simplificado.
  # O grafo deve ser no formato { devedor => { credor => montante } }.
  # @param debt_graph [Hash<User, Hash<User, BigDecimal>>] O grafo de dívidas a ser simplificado.
  # @param tolerance [BigDecimal] Tolerância para considerar um montante como zero.
  def initialize(debt_graph, tolerance: BigDecimal('0.01'))
    @debt_graph = deep_copy_hash(debt_graph) # Trabalha com uma cópia para não alterar o original
    @tolerance = tolerance
  end

  # Simplifica o grafo de dívidas identificando e removendo ciclos e combinando transações diretas.
  # @return [Hash<User, Hash<User, BigDecimal>>] O grafo de dívidas simplificado.
  def simplify_transactions
    remove_direct_opposing_debts # Simplifica dívidas diretas (A deve a B, B deve a A)
    find_and_remove_cycles # Lógica principal para alta complexidade ciclomática
    # Podemos adicionar mais lógica de simplificação aqui, como consolidar múltiplos devedores/credores para um único.
    clean_zero_debts
    @debt_graph
  end

  private

  # Realiza uma cópia profunda do hash para evitar efeitos colaterais.
  def deep_copy_hash(hash)
    Marshal.load(Marshal.dump(hash))
  end

  # Remove dívidas diretas opostas (A deve a B, B deve a A) simplificando-as para uma única transação líquida.
  def remove_direct_opposing_debts
    @debt_graph.keys.each do |user1|
      @debt_graph[user1].keys.each do |user2|
        next if user1 == user2 # Não se deve a si mesmo

        if @debt_graph[user2] && @debt_graph[user2][user1] &&
           @debt_graph[user1][user2] > @tolerance && @debt_graph[user2][user1] > @tolerance
          # Ambos devem um ao outro, simplifica a transação
          debt1_to_2 = @debt_graph[user1][user2]
          debt2_to_1 = @debt_graph[user2][user1]

          if debt1_to_2 > debt2_to_1
            @debt_graph[user1][user2] = debt1_to_2 - debt2_to_1
            @debt_graph[user2].delete(user1)
          else
            @debt_graph[user2][user1] = debt2_to_1 - debt1_to_2
            @debt_graph[user1].delete(user2)
          end
        end
      end
    end
  end

  # Algoritmo principal para encontrar e remover ciclos de dívidas (complexidade ciclomática alta).
  # Utiliza uma abordagem de DFS para detecção de ciclos e remoção.
  def find_and_remove_cycles
    # Garante que os usuários estejam em uma ordem consistente para o DFS
    users = @debt_graph.keys.uniq
    visited = {} # Mantém o controle de nós visitados no DFS
    recursion_stack = {} # Mantém o controle de nós na pilha de recursão para detectar ciclos
    path = [] # Armazena o caminho atual no DFS

    # Itera sobre todos os usuários para garantir que todos os componentes conectados sejam visitados
    users.each do |start_node|
      # Aumenta a complexidade: a busca por ciclos envolve múltiplas chamadas recursivas
      # e manipulação de estado em cada chamada.
      dfs_detect_and_remove_cycle(start_node, visited, recursion_stack, path)
    end
  end

  # Função auxiliar de DFS para detectar e remover ciclos.
  # @param u [User] O nó atual no DFS.
  # @param visited [Hash] Hash de nós já visitados no DFS global.
  # @param recursion_stack [Hash] Hash de nós atualmente na pilha de recursão (para detecção de ciclo).
  # @param path [Array<User>] O caminho atual percorrido no DFS.
  def dfs_detect_and_remove_cycle(u, visited, recursion_stack, path)
    visited[u] = true
    recursion_stack[u] = true
    path << u

    # Itera sobre os vizinhos do nó atual (aqueles a quem ele deve)
    if @debt_graph[u]
      @debt_graph[u].keys.each do |v|
        next unless @debt_graph[u][v] > @tolerance # Ignora dívidas insignificantes

        if !visited[v]
          # Se o vizinho não foi visitado, continua o DFS
          dfs_detect_and_remove_cycle(v, visited, recursion_stack, path)
        elsif recursion_stack[v]
          # CICLO DETECTADO! (u -> v, e v já está na pilha de recursão)
          process_cycle(u, v, path)
        end
      end
    end

    # Remove o nó da pilha de recursão ao sair do DFS para ele
    recursion_stack.delete(u)
    path.pop # Remove o nó do caminho ao retornar da recursão
  end

  # Processa um ciclo de dívidas, removendo o menor valor de todas as arestas no ciclo.
  # @param cycle_start_node [User] O nó onde o ciclo foi detectado.
  # @param cycle_end_node [User] O nó que fechou o ciclo.
  # @param current_path [Array<User>] O caminho completo que levou à detecção do ciclo.
  def process_cycle(cycle_start_node, cycle_end_node, current_path)
    # Encontra os nós que formam o ciclo completo
    cycle = []
    # Adiciona os nós do caminho a partir do cycle_end_node (inclusive) até o cycle_start_node (inclusive)
    start_index = current_path.index(cycle_end_node)
    return unless start_index # Garante que o cycle_end_node está no caminho

    cycle = current_path[start_index..-1]
    # O ciclo é: cycle_end_node -> ... -> cycle_start_node -> cycle_end_node

    # Encontra o menor valor de dívida em todas as arestas do ciclo
    min_debt_in_cycle = BigDecimal('Infinity')
    cycle.each_cons(2) do |from_node, to_node|
      # Verifica a dívida de from_node para to_node
      min_debt_in_cycle = [min_debt_in_cycle, @debt_graph[from_node][to_node]].min
    end
    # Não esquecer a aresta que fecha o ciclo (do último nó para o primeiro)
    min_debt_in_cycle = [min_debt_in_cycle, @debt_graph[cycle.last][cycle.first]].min

    # Reduz todas as dívidas no ciclo pelo min_debt_in_cycle
    cycle.each_cons(2) do |from_node, to_node|
      @debt_graph[from_node][to_node] -= min_debt_in_cycle
    end
    @debt_graph[cycle.last][cycle.first] -= min_debt_in_cycle # Aresta de fechamento

    Rails.logger.info("Ciclo removido: #{cycle.map(&:id).join(' -> ')} -> #{cycle.first.id}. Valor ajustado: #{min_debt_in_cycle}")
  end

  # Limpa todas as dívidas que se tornaram zero ou insignificantes após a simplificação.
  def clean_zero_debts
    @debt_graph.keys.each do |debtor|
      @debt_graph[debtor].keys.each do |creditor|
        if @debt_graph[debtor][creditor] <= @tolerance
          @debt_graph[debtor].delete(creditor)
        end
      end
      @debt_graph.delete(debtor) if @debt_graph[debtor].empty?
    end
  end
end
