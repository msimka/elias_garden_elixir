defmodule Elias.ApeHarmony do
  @moduledoc """
  APE HARMONY - Private blockchain for ELIAS distributed coordination
  
  Logs all distributed activity for:
  - Request pool operations
  - Rule synchronization 
  - Node communications
  - Performance metrics
  - Future airdrop allocation tracking
  """
  
  use GenServer
  require Logger

  @doc """
  Start the APE HARMONY blockchain service
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Record an event to the blockchain
  """
  def record_event(event_type, data, node \\ node()) do
    GenServer.cast(__MODULE__, {:record_event, event_type, data, node})
  end

  @doc """
  Get blockchain status and metrics
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @doc """
  Get recent blocks
  """
  def get_recent_blocks(count \\ 10) do
    GenServer.call(__MODULE__, {:get_recent_blocks, count})
  end

  @doc """
  Get contribution score for a node (future airdrop basis)
  """
  def get_contribution_score(node_name) do
    GenServer.call(__MODULE__, {:get_contribution_score, node_name})
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("⛓️  APE HARMONY Blockchain starting...")
    
    # Load existing blockchain or create genesis block
    blockchain = load_or_create_blockchain()
    
    state = %{
      blockchain: blockchain,
      pending_transactions: [],
      mining_difficulty: 4,  # Number of leading zeros required
      block_time: 30_000,    # Target block time in milliseconds
      last_block_time: DateTime.utc_now(),
      node_contributions: %{},
      total_transactions: length(List.flatten(Enum.map(blockchain, & &1.transactions)))
    }
    
    # Schedule periodic mining
    schedule_mining()
    
    Logger.info("✅ APE HARMONY initialized with #{length(blockchain)} blocks")
    {:ok, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      total_blocks: length(state.blockchain),
      pending_transactions: length(state.pending_transactions),
      total_transactions: state.total_transactions,
      mining_difficulty: state.mining_difficulty,
      last_block_hash: get_last_block_hash(state.blockchain),
      node_count: map_size(state.node_contributions)
    }
    
    {:reply, status, state}
  end

  @impl true
  def handle_call({:get_recent_blocks, count}, _from, state) do
    recent_blocks = state.blockchain |> Enum.take(-count) |> Enum.reverse()
    {:reply, recent_blocks, state}
  end

  @impl true
  def handle_call({:get_contribution_score, node_name}, _from, state) do
    node_atom = if is_binary(node_name), do: String.to_atom(node_name), else: node_name
    score = Map.get(state.node_contributions, node_atom, 0)
    {:reply, score, state}
  end

  @impl true
  def handle_cast({:record_event, event_type, data, node}, state) do
    # Create transaction for the event
    transaction = %{
      id: generate_transaction_id(),
      type: event_type,
      data: sanitize_data(data),
      node: node,
      timestamp: DateTime.utc_now(),
      hash: nil  # Will be set when transaction is added
    }
    
    # Add hash to transaction
    transaction_with_hash = %{transaction | hash: hash_transaction(transaction)}
    
    Logger.debug("⛓️  Recording APE HARMONY event: #{event_type} from #{node}")
    
    # Add to pending transactions
    new_pending = [transaction_with_hash | state.pending_transactions]
    
    # Update contribution score for the node
    current_score = Map.get(state.node_contributions, node, 0)
    contribution_points = calculate_contribution_points(event_type)
    new_contributions = Map.put(state.node_contributions, node, current_score + contribution_points)
    
    new_state = %{state | 
      pending_transactions: new_pending,
      node_contributions: new_contributions
    }
    
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:mine_block, state) do
    schedule_mining()
    
    if length(state.pending_transactions) > 0 do
      Logger.info("⛓️  Mining new APE HARMONY block...")
      
      # Create new block
      new_block = create_block(state.pending_transactions, state.blockchain, state.mining_difficulty)
      
      case new_block do
        {:ok, block} ->
          Logger.info("✅ Block mined: ##{block.index} with #{length(block.transactions)} transactions")
          
          new_blockchain = [block | state.blockchain]
          total_tx = state.total_transactions + length(state.pending_transactions)
          
          # Persist blockchain
          persist_blockchain(new_blockchain)
          
          # Broadcast new block to network
          broadcast_block(block)
          
          new_state = %{state | 
            blockchain: new_blockchain,
            pending_transactions: [],
            last_block_time: DateTime.utc_now(),
            total_transactions: total_tx
          }
          
          {:noreply, new_state}
          
        {:error, reason} ->
          Logger.error("❌ Block mining failed: #{inspect(reason)}")
          {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("🔄 Unhandled message in APE HARMONY: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private Functions

  defp load_or_create_blockchain do
    blockchain_file = Path.join(:code.priv_dir(:elias), "ape_harmony_blockchain.json")
    
    case File.read(blockchain_file) do
      {:ok, content} ->
        case Jason.decode(content, keys: :atoms) do
          {:ok, blockchain} -> 
            Logger.info("📂 Loaded existing APE HARMONY blockchain")
            blockchain
          {:error, _} ->
            Logger.info("🌱 Creating new APE HARMONY blockchain")
            create_genesis_blockchain()
        end
      {:error, _} ->
        Logger.info("🌱 Creating new APE HARMONY blockchain")
        create_genesis_blockchain()
    end
  end

  defp create_genesis_blockchain do
    genesis_block = %{
      index: 0,
      timestamp: DateTime.utc_now(),
      transactions: [%{
        id: "genesis",
        type: :genesis,
        data: %{message: "APE HARMONY Genesis - ELIAS v2.0 Launch"},
        node: :system,
        timestamp: DateTime.utc_now(),
        hash: "0000000000000000000000000000000000000000000000000000000000000000"
      }],
      previous_hash: "0",
      hash: nil,
      nonce: 0,
      difficulty: 4
    }
    
    # Calculate genesis block hash
    genesis_with_hash = %{genesis_block | hash: hash_block(genesis_block)}
    
    [genesis_with_hash]
  end

  defp create_block(transactions, blockchain, difficulty) do
    previous_block = List.first(blockchain)
    previous_hash = if previous_block, do: previous_block.hash, else: "0"
    
    block = %{
      index: length(blockchain),
      timestamp: DateTime.utc_now(),
      transactions: Enum.reverse(transactions),  # Reverse to maintain order
      previous_hash: previous_hash,
      hash: nil,
      nonce: 0,
      difficulty: difficulty
    }
    
    # Mine the block (find valid hash with required difficulty)
    case mine_block(block, difficulty) do
      {:ok, mined_block} -> {:ok, mined_block}
      error -> error
    end
  end

  defp mine_block(block, difficulty, max_attempts \\ 100_000) do
    target = String.duplicate("0", difficulty)
    
    mine_attempt(block, target, 0, max_attempts)
  end

  defp mine_attempt(block, target, nonce, max_attempts) when nonce < max_attempts do
    candidate_block = %{block | nonce: nonce}
    hash = hash_block(candidate_block)
    
    if String.starts_with?(hash, target) do
      {:ok, %{candidate_block | hash: hash}}
    else
      mine_attempt(block, target, nonce + 1, max_attempts)
    end
  end

  defp mine_attempt(_block, _target, _nonce, _max_attempts) do
    {:error, :mining_timeout}
  end

  defp hash_block(block) do
    content = "#{block.index}#{block.timestamp}#{inspect(block.transactions)}#{block.previous_hash}#{block.nonce}"
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end

  defp hash_transaction(transaction) do
    content = "#{transaction.id}#{transaction.type}#{inspect(transaction.data)}#{transaction.node}#{transaction.timestamp}"
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end

  defp generate_transaction_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp sanitize_data(data) when is_map(data) do
    # Remove sensitive information before blockchain storage
    data
    |> Map.drop([:api_key, :password, :secret, :token])
    |> Enum.reduce(%{}, fn
      {k, v}, acc when is_binary(v) and byte_size(v) > 1000 ->
        # Hash large payloads
        Map.put(acc, k, %{hash: hash_large_payload(v), size: byte_size(v)})
      {k, v}, acc ->
        Map.put(acc, k, v)
    end)
  end
  defp sanitize_data(data), do: data

  defp hash_large_payload(payload) do
    :crypto.hash(:sha256, payload) |> Base.encode16(case: :lower)
  end

  defp calculate_contribution_points(event_type) do
    case event_type do
      :request_submitted -> 1
      :request_completed -> 2
      :rule_synchronized -> 3
      :node_joined -> 5
      :block_mined -> 10
      _ -> 1
    end
  end

  defp get_last_block_hash([]), do: "0"
  defp get_last_block_hash([block | _]), do: block.hash

  defp persist_blockchain(blockchain) do
    blockchain_file = Path.join(:code.priv_dir(:elias), "ape_harmony_blockchain.json")
    content = Jason.encode!(blockchain, pretty: true)
    File.write!(blockchain_file, content)
  end

  defp broadcast_block(block) do
    # Broadcast new block to all connected nodes
    Node.list()
    |> Enum.each(fn node ->
      :rpc.cast(node, GenServer, :cast, [__MODULE__, {:new_block, block}])
    end)
  end

  defp schedule_mining do
    # Mine new blocks every 30 seconds
    Process.send_after(self(), :mine_block, 30_000)
  end
end