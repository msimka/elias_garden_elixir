defmodule EliasCore.ApeHarmony do
  @moduledoc """
  APE HARMONY - Private blockchain for distributed coordination logging
  Logs all P2P activity, manager events, and system operations across the federation
  """
  
  use GenServer
  require Logger

  defstruct [
    :blockchain,
    :current_block,
    :mining_difficulty,
    :last_block_time,
    :pending_transactions,
    :node_contributions
  ]

  # Public API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def record_event(event_type, data, node \\ node()) do
    GenServer.cast(__MODULE__, {:record_event, event_type, data, node})
  end

  def get_blockchain do
    GenServer.call(__MODULE__, :get_blockchain)
  end

  def get_block(block_hash) do
    GenServer.call(__MODULE__, {:get_block, block_hash})
  end

  def get_chain_status do
    GenServer.call(__MODULE__, :get_chain_status)
  end

  def get_node_contributions(node \\ node()) do
    GenServer.call(__MODULE__, {:get_contributions, node})
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("⛓️ APE HARMONY blockchain starting...")
    
    # Load existing blockchain or create genesis block
    blockchain = load_or_create_blockchain()
    
    state = %__MODULE__{
      blockchain: blockchain,
      current_block: nil,
      mining_difficulty: get_initial_difficulty(),
      last_block_time: DateTime.utc_now(),
      pending_transactions: [],
      node_contributions: %{}
    }
    
    # Only mine blocks on full nodes
    if EliasCore.full_node?() do
      schedule_mining()
    end
    
    Logger.info("✅ APE HARMONY blockchain initialized with #{length(blockchain)} blocks")
    {:ok, state}
  end

  @impl true
  def handle_call(:get_blockchain, _from, state) do
    {:reply, state.blockchain, state}
  end

  def handle_call({:get_block, block_hash}, _from, state) do
    block = Enum.find(state.blockchain, fn block -> block.hash == block_hash end)
    {:reply, block, state}
  end

  def handle_call(:get_chain_status, _from, state) do
    status = %{
      blocks_count: length(state.blockchain),
      pending_transactions: length(state.pending_transactions),
      mining_difficulty: state.mining_difficulty,
      last_block_time: state.last_block_time,
      node_type: EliasCore.node_type(),
      is_mining: EliasCore.full_node?()
    }
    {:reply, status, state}
  end

  def handle_call({:get_contributions, node}, _from, state) do
    contributions = Map.get(state.node_contributions, node, %{
      blocks_mined: 0,
      events_logged: 0,
      total_contribution_score: 0
    })
    {:reply, contributions, state}
  end

  @impl true
  def handle_cast({:record_event, event_type, data, event_node}, state) do
    # Create transaction for the event
    transaction = create_transaction(event_type, data, event_node)
    
    # Add to pending transactions
    pending_transactions = [transaction | state.pending_transactions]
    
    # Update node contributions
    node_contributions = update_contributions(
      state.node_contributions, 
      event_node, 
      :event_logged
    )
    
    Logger.debug("📝 Event recorded: #{event_type} from #{event_node}")
    
    new_state = %{state | 
      pending_transactions: pending_transactions,
      node_contributions: node_contributions
    }
    
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:mine_block, state) do
    if EliasCore.full_node?() and length(state.pending_transactions) > 0 do
      Logger.info("⛏️ Mining new block with #{length(state.pending_transactions)} transactions...")
      
      # Create new block
      case mine_new_block(state) do
        {:ok, new_block, updated_state} ->
          # Broadcast new block to other nodes
          EliasCore.P2P.broadcast_message({:new_block, new_block})
          
          Logger.info("✅ Block #{new_block.height} mined successfully: #{new_block.hash}")
          
          # Schedule next mining cycle
          schedule_mining()
          
          {:noreply, updated_state}
        
        {:error, reason} ->
          Logger.error("❌ Block mining failed: #{reason}")
          schedule_mining()
          {:noreply, state}
      end
    else
      # No transactions to mine or not a full node
      schedule_mining()
      {:noreply, state}
    end
  end

  def handle_info({:new_block, block}, state) do
    # Received new block from another node
    Logger.info("📦 Received new block #{block.height} from network")
    
    case validate_and_add_block(block, state) do
      {:ok, updated_state} ->
        Logger.info("✅ Block #{block.height} validated and added to chain")
        {:noreply, updated_state}
      
      {:error, reason} ->
        Logger.warning("⚠️ Block #{block.height} rejected: #{reason}")
        {:noreply, state}
    end
  end

  def handle_info(msg, state) do
    Logger.debug("🔄 Unhandled blockchain message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private Functions

  defp load_or_create_blockchain do
    blockchain_file = get_blockchain_file()
    
    case File.read(blockchain_file) do
      {:ok, content} ->
        blockchain_data = Jason.decode!(content, keys: :atoms)
        Logger.info("📖 Loaded existing blockchain with #{length(blockchain_data)} blocks")
        blockchain_data
      
      {:error, _} ->
        Logger.info("🆕 Creating genesis block...")
        genesis_block = create_genesis_block()
        save_blockchain([genesis_block])
        [genesis_block]
    end
  end

  defp create_genesis_block do
    %{
      height: 0,
      timestamp: DateTime.utc_now(),
      previous_hash: "0000000000000000000000000000000000000000000000000000000000000000",
      transactions: [],
      merkle_root: "genesis",
      nonce: 0,
      hash: "00000000afe91b38b8bb5c6b0e65af9ea4a9bda70f6bcf68b4b5de936aff8eb7",
      difficulty: 4,
      miner: node(),
      mining_time: 0
    }
  end

  defp create_transaction(event_type, data, event_node) do
    %{
      id: generate_transaction_id(),
      timestamp: DateTime.utc_now(),
      event_type: event_type,
      data: data,
      node: event_node,
      signature: generate_signature(event_type, data, event_node)
    }
  end

  defp mine_new_block(state) do
    previous_block = List.first(state.blockchain)
    
    new_block = %{
      height: previous_block.height + 1,
      timestamp: DateTime.utc_now(),
      previous_hash: previous_block.hash,
      transactions: state.pending_transactions,
      merkle_root: calculate_merkle_root(state.pending_transactions),
      nonce: 0,
      difficulty: state.mining_difficulty,
      miner: node()
    }
    
    # Mine the block (find valid nonce)
    start_time = System.monotonic_time()
    
    case mine_block(new_block, state.mining_difficulty) do
      {:ok, mined_block} ->
        mining_time = System.monotonic_time() - start_time
        final_block = Map.put(mined_block, :mining_time, mining_time)
        
        # Update state
        new_blockchain = [final_block | state.blockchain]
        save_blockchain(new_blockchain)
        
        # Update node contributions
        node_contributions = update_contributions(
          state.node_contributions,
          node(),
          :block_mined
        )
        
        updated_state = %{state |
          blockchain: new_blockchain,
          pending_transactions: [],
          last_block_time: DateTime.utc_now(),
          node_contributions: node_contributions
        }
        
        {:ok, final_block, updated_state}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp mine_block(block, difficulty, max_attempts \\ 100_000) do
    target = String.duplicate("0", difficulty)
    mine_attempt(block, target, 0, max_attempts)
  end

  defp mine_attempt(block, target, nonce, max_attempts) when nonce < max_attempts do
    candidate_block = %{block | nonce: nonce}
    hash = calculate_block_hash(candidate_block)
    
    if String.starts_with?(hash, target) do
      {:ok, %{candidate_block | hash: hash}}
    else
      mine_attempt(block, target, nonce + 1, max_attempts)
    end
  end

  defp mine_attempt(_block, _target, _nonce, _max_attempts) do
    {:error, "Mining failed - max attempts reached"}
  end

  defp calculate_block_hash(block) do
    hash_input = "#{block.height}#{block.timestamp}#{block.previous_hash}#{block.merkle_root}#{block.nonce}"
    :crypto.hash(:sha256, hash_input) |> Base.encode16(case: :lower)
  end

  defp calculate_merkle_root([]), do: "empty"
  defp calculate_merkle_root(transactions) do
    transactions
    |> Enum.map(&Jason.encode!/1)
    |> Enum.map(fn tx -> :crypto.hash(:sha256, tx) |> Base.encode16(case: :lower) end)
    |> calculate_merkle_tree()
  end

  defp calculate_merkle_tree([hash]), do: hash
  defp calculate_merkle_tree(hashes) do
    if rem(length(hashes), 2) == 1 do
      calculate_merkle_tree(hashes ++ [List.last(hashes)])
    else
      hashes
      |> Enum.chunk_every(2)
      |> Enum.map(fn [left, right] -> 
        :crypto.hash(:sha256, left <> right) |> Base.encode16(case: :lower)
      end)
      |> calculate_merkle_tree()
    end
  end

  defp validate_and_add_block(block, state) do
    previous_block = List.first(state.blockchain)
    
    cond do
      block.height != previous_block.height + 1 ->
        {:error, "Invalid block height"}
      
      block.previous_hash != previous_block.hash ->
        {:error, "Invalid previous hash"}
      
      not valid_proof_of_work?(block) ->
        {:error, "Invalid proof of work"}
      
      true ->
        new_blockchain = [block | state.blockchain]
        save_blockchain(new_blockchain)
        
        updated_state = %{state |
          blockchain: new_blockchain,
          last_block_time: DateTime.utc_now()
        }
        
        {:ok, updated_state}
    end
  end

  defp valid_proof_of_work?(block) do
    hash = calculate_block_hash(block)
    target = String.duplicate("0", block.difficulty)
    hash == block.hash and String.starts_with?(hash, target)
  end

  defp update_contributions(contributions, node, action) do
    current = Map.get(contributions, node, %{
      blocks_mined: 0,
      events_logged: 0,
      total_contribution_score: 0
    })
    
    updated = case action do
      :block_mined ->
        %{current |
          blocks_mined: current.blocks_mined + 1,
          total_contribution_score: current.total_contribution_score + 10
        }
      
      :event_logged ->
        %{current |
          events_logged: current.events_logged + 1,
          total_contribution_score: current.total_contribution_score + 1
        }
    end
    
    Map.put(contributions, node, updated)
  end

  defp schedule_mining do
    # Mine new block every 30 seconds (configurable)
    Process.send_after(self(), :mine_block, 30_000)
  end

  defp get_initial_difficulty, do: 4

  defp generate_transaction_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp generate_signature(event_type, data, node) do
    signature_input = "#{event_type}#{Jason.encode!(data)}#{node}"
    :crypto.hash(:sha256, signature_input) |> Base.encode16(case: :lower)
  end

  defp get_blockchain_file do
    case EliasCore.node_type() do
      :full_node -> "/tmp/ape_harmony_blockchain.json"
      :client -> "/tmp/ape_harmony_light.json"
    end
  end

  defp save_blockchain(blockchain) do
    blockchain_file = get_blockchain_file()
    content = Jason.encode!(blockchain, pretty: true)
    File.write!(blockchain_file, content)
  end
end