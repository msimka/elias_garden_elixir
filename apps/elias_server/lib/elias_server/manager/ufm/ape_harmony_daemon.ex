defmodule EliasServer.Manager.UFM.ApeHarmonyDaemon do
  @moduledoc """
  UFM APE HARMONY Sub-Daemon - Always-on blockchain operations and distributed logging
  
  Responsibilities:
  - APE HARMONY blockchain consensus and validation
  - Distributed event logging across ELIAS federation
  - Token economics and transaction processing
  - Smart contract execution for ELIAS workflows
  - Hot-reload from UFM_ApeHarmony.md spec
  
  Follows "always-on daemon" philosophy - never stops mining harmony!
  """
  
  use GenServer
  require Logger
  
  alias EliasServer.Manager.SupervisorHelper
  
  defstruct [
    :rules,
    :last_updated,
    :checksum,
    :blockchain_state,
    :pending_transactions,
    :mining_state,
    :consensus_state,
    :event_log_buffer,
    :block_validation_timer,
    :consensus_timer,
    :mining_timer
  ]
  
  @spec_file Path.join([Application.app_dir(:elias_server), "priv", "manager_specs", "UFM_ApeHarmony.md"])
  
  # Public API
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end
  
  def record_event(event_type, event_data) do
    GenServer.cast(__MODULE__, {:record_event, event_type, event_data})
  end
  
  def get_blockchain_status do
    GenServer.call(__MODULE__, :get_blockchain_status)
  end
  
  def get_pending_transactions do
    GenServer.call(__MODULE__, :get_pending_transactions)
  end
  
  def submit_transaction(transaction) do
    GenServer.call(__MODULE__, {:submit_transaction, transaction})
  end
  
  def get_harmony_balance(node_id) do
    GenServer.call(__MODULE__, {:get_harmony_balance, node_id})
  end
  
  def get_consensus_state do
    GenServer.call(__MODULE__, :get_consensus_state)
  end
  
  def force_mining_cycle do
    GenServer.cast(__MODULE__, :force_mining_cycle)
  end
  
  def reload_rules do
    GenServer.cast(__MODULE__, :reload_rules)
  end
  
  # GenServer Callbacks
  
  @impl true
  def init(state) do
    Logger.info("⛓️ UFM.ApeHarmonyDaemon: Starting always-on APE HARMONY blockchain daemon")
    
    # Register in sub-daemon registry
    SupervisorHelper.register_process(:ufm_subdaemons, :ape_harmony_daemon, self())
    
    # Load APE HARMONY rules from hierarchical spec
    new_state = load_ape_harmony_rules(state)
    
    # Initialize blockchain state
    initial_state = %{new_state |
      blockchain_state: initialize_blockchain(new_state.rules),
      pending_transactions: [],
      mining_state: initialize_mining_state(new_state.rules),
      consensus_state: initialize_consensus_state(),
      event_log_buffer: []
    }
    
    # Start continuous blockchain processes
    final_state = start_blockchain_timers(initial_state)
    
    # Initialize genesis block if needed
    final_state = ensure_genesis_block(final_state)
    
    Logger.info("✅ UFM.ApeHarmonyDaemon: APE HARMONY blockchain active - mining harmony across the federation!")
    {:ok, final_state}
  end
  
  @impl true
  def handle_call(:get_blockchain_status, _from, state) do
    status = %{
      chain_height: length(state.blockchain_state.chain),
      pending_tx_count: length(state.pending_transactions),
      mining_active: state.mining_state.active,
      consensus_round: state.consensus_state.current_round,
      harmony_supply: calculate_total_harmony_supply(state.blockchain_state),
      last_block_hash: get_last_block_hash(state.blockchain_state),
      node_validators: map_size(state.consensus_state.validators)
    }
    {:reply, status, state}
  end
  
  def handle_call(:get_pending_transactions, _from, state) do
    {:reply, state.pending_transactions, state}
  end
  
  def handle_call({:submit_transaction, transaction}, _from, state) do
    case validate_transaction(transaction, state.blockchain_state) do
      {:ok, validated_tx} ->
        updated_pending = [validated_tx | state.pending_transactions]
        Logger.info("💰 UFM.ApeHarmonyDaemon: New transaction submitted - #{validated_tx.type}")
        {:reply, {:ok, validated_tx.id}, %{state | pending_transactions: updated_pending}}
        
      {:error, reason} ->
        Logger.warning("❌ UFM.ApeHarmonyDaemon: Transaction rejected: #{reason}")
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call({:get_harmony_balance, node_id}, _from, state) do
    balance = calculate_node_harmony_balance(node_id, state.blockchain_state)
    {:reply, balance, state}
  end
  
  def handle_call(:get_consensus_state, _from, state) do
    {:reply, state.consensus_state, state}
  end
  
  @impl true
  def handle_cast(:reload_rules, state) do
    Logger.info("🔄 UFM.ApeHarmonyDaemon: Hot-reloading APE HARMONY rules")
    new_state = load_ape_harmony_rules(state)
    updated_state = apply_ape_harmony_rule_changes(state, new_state)
    {:noreply, updated_state}
  end
  
  def handle_cast({:record_event, event_type, event_data}, state) do
    # Buffer events for inclusion in next block
    event_entry = %{
      type: event_type,
      data: event_data,
      timestamp: DateTime.utc_now(),
      node: Node.self()
    }
    
    updated_buffer = [event_entry | state.event_log_buffer]
    
    # If buffer is full, trigger mining cycle
    buffer_limit = Map.get(state.rules, :event_buffer_limit, 100)
    if length(updated_buffer) >= buffer_limit do
      GenServer.cast(self(), :force_mining_cycle)
    end
    
    Logger.debug("📝 UFM.ApeHarmonyDaemon: Recorded #{event_type} event for blockchain")
    {:noreply, %{state | event_log_buffer: updated_buffer}}
  end
  
  def handle_cast(:force_mining_cycle, state) do
    Logger.info("⛏️ UFM.ApeHarmonyDaemon: Force starting mining cycle")
    updated_state = attempt_block_mining(state)
    {:noreply, updated_state}
  end
  
  @impl true
  def handle_info(:mining_cycle, state) do
    # Continuous mining - the heart of APE HARMONY
    updated_state = attempt_block_mining(state)
    
    # Schedule next mining cycle
    mining_timer = schedule_mining_cycle(updated_state.rules)
    final_state = %{updated_state | mining_timer: mining_timer}
    
    {:noreply, final_state}
  end
  
  def handle_info(:consensus_cycle, state) do
    # Distributed consensus coordination
    updated_state = run_consensus_round(state)
    
    # Schedule next consensus cycle
    consensus_timer = schedule_consensus_cycle(updated_state.rules)
    final_state = %{updated_state | consensus_timer: consensus_timer}
    
    {:noreply, final_state}
  end
  
  def handle_info(:block_validation_cycle, state) do
    # Validate blocks received from other nodes
    updated_state = validate_incoming_blocks(state)
    
    # Schedule next validation cycle
    validation_timer = schedule_block_validation(updated_state.rules)
    final_state = %{updated_state | block_validation_timer: validation_timer}
    
    {:noreply, final_state}
  end
  
  def handle_info({:block_received, block, sender_node}, state) do
    Logger.info("📦 UFM.ApeHarmonyDaemon: Received new block from #{sender_node}")
    updated_state = process_incoming_block(block, sender_node, state)
    {:noreply, updated_state}
  end
  
  def handle_info({:consensus_vote, vote, voter_node}, state) do
    Logger.debug("🗳️ UFM.ApeHarmonyDaemon: Received consensus vote from #{voter_node}")
    updated_state = process_consensus_vote(vote, voter_node, state)
    {:noreply, updated_state}
  end
  
  # Private Functions
  
  defp load_ape_harmony_rules(state) do
    case File.read(@spec_file) do
      {:ok, content} ->
        {rules, checksum} = parse_ape_harmony_md_rules(content)
        %{state |
          rules: rules,
          last_updated: DateTime.utc_now(),
          checksum: checksum
        }
      {:error, reason} ->
        Logger.error("❌ UFM.ApeHarmonyDaemon: Could not load UFM_ApeHarmony.md: #{reason}")
        # Use default APE HARMONY rules
        %{state |
          rules: default_ape_harmony_rules(),
          last_updated: DateTime.utc_now()
        }
    end
  end
  
  defp parse_ape_harmony_md_rules(content) do
    # Extract APE HARMONY-specific YAML configuration
    [frontmatter_str | _] = String.split(content, "---", parts: 3, trim: true)
    
    frontmatter = YamlElixir.read_from_string(frontmatter_str) || %{}
    checksum = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
    
    rules = %{
      mining_interval: get_in(frontmatter, ["ape_harmony", "mining_interval"]) || 60000,
      consensus_interval: get_in(frontmatter, ["ape_harmony", "consensus_interval"]) || 30000,
      validation_interval: get_in(frontmatter, ["ape_harmony", "validation_interval"]) || 15000,
      block_reward: get_in(frontmatter, ["ape_harmony", "block_reward"]) || 10.0,
      transaction_fee: get_in(frontmatter, ["ape_harmony", "transaction_fee"]) || 0.1,
      consensus_threshold: get_in(frontmatter, ["ape_harmony", "consensus_threshold"]) || 0.67,
      event_buffer_limit: get_in(frontmatter, ["ape_harmony", "event_buffer_limit"]) || 100,
      mining_difficulty: get_in(frontmatter, ["ape_harmony", "mining_difficulty"]) || 2
    }
    
    {rules, checksum}
  end
  
  defp default_ape_harmony_rules do
    %{
      mining_interval: 60000,        # 1 minute - regular block mining
      consensus_interval: 30000,     # 30 seconds - consensus coordination
      validation_interval: 15000,    # 15 seconds - block validation
      block_reward: 10.0,            # HARMONY tokens per block
      transaction_fee: 0.1,          # Fee per transaction
      consensus_threshold: 0.67,     # 67% consensus required
      event_buffer_limit: 100,       # Events per block
      mining_difficulty: 2           # Mining difficulty level
    }
  end
  
  defp initialize_blockchain(rules) do
    %{
      chain: [],                     # Blockchain ledger
      balances: %{},                 # Node HARMONY balances
      smart_contracts: %{},          # Deployed smart contracts
      last_block_time: DateTime.utc_now(),
      total_supply: 0.0,
      network_hash_rate: 0.0
    }
  end
  
  defp initialize_mining_state(rules) do
    %{
      active: true,
      difficulty: Map.get(rules, :mining_difficulty, 2),
      current_target: calculate_mining_target(2),
      blocks_mined: 0,
      total_hash_attempts: 0
    }
  end
  
  defp initialize_consensus_state do
    %{
      current_round: 0,
      validators: discover_validator_nodes(),
      votes: %{},
      consensus_reached: false,
      last_consensus_time: DateTime.utc_now()
    }
  end
  
  defp start_blockchain_timers(state) do
    mining_timer = schedule_mining_cycle(state.rules)
    consensus_timer = schedule_consensus_cycle(state.rules)
    validation_timer = schedule_block_validation(state.rules)
    
    %{state |
      mining_timer: mining_timer,
      consensus_timer: consensus_timer,
      block_validation_timer: validation_timer
    }
  end
  
  defp schedule_mining_cycle(rules) do
    interval = Map.get(rules, :mining_interval, 60000)
    Process.send_after(self(), :mining_cycle, interval)
  end
  
  defp schedule_consensus_cycle(rules) do
    interval = Map.get(rules, :consensus_interval, 30000)
    Process.send_after(self(), :consensus_cycle, interval)
  end
  
  defp schedule_block_validation(rules) do
    interval = Map.get(rules, :validation_interval, 15000)
    Process.send_after(self(), :block_validation_cycle, interval)
  end
  
  defp ensure_genesis_block(state) do
    if length(state.blockchain_state.chain) == 0 do
      Logger.info("🌱 UFM.ApeHarmonyDaemon: Creating APE HARMONY genesis block")
      genesis_block = create_genesis_block(state.rules)
      updated_chain = [genesis_block]
      updated_blockchain = %{state.blockchain_state | chain: updated_chain}
      %{state | blockchain_state: updated_blockchain}
    else
      state
    end
  end
  
  defp create_genesis_block(rules) do
    %{
      index: 0,
      timestamp: DateTime.utc_now(),
      previous_hash: "0000000000000000000000000000000000000000000000000000000000000000",
      hash: "ape_harmony_genesis_block_hash",
      transactions: [create_genesis_transaction(rules)],
      events: [create_genesis_event()],
      nonce: 0,
      difficulty: Map.get(rules, :mining_difficulty, 2),
      miner: Node.self(),
      reward: Map.get(rules, :block_reward, 10.0)
    }
  end
  
  defp create_genesis_transaction(rules) do
    %{
      id: "genesis_tx_" <> generate_transaction_id(),
      type: :genesis_reward,
      from: :network,
      to: Node.self(),
      amount: Map.get(rules, :block_reward, 10.0),
      fee: 0.0,
      timestamp: DateTime.utc_now(),
      signature: "genesis_signature"
    }
  end
  
  defp create_genesis_event do
    %{
      type: :ape_harmony_genesis,
      data: %{
        network_name: "ELIAS APE HARMONY",
        genesis_node: Node.self(),
        timestamp: DateTime.utc_now(),
        version: "1.0.0"
      },
      timestamp: DateTime.utc_now(),
      node: Node.self()
    }
  end
  
  defp attempt_block_mining(state) do
    if state.mining_state.active and should_mine_block?(state) do
      Logger.info("⛏️ UFM.ApeHarmonyDaemon: Starting block mining process")
      
      # Prepare transactions for inclusion in block
      {selected_transactions, remaining_pending} = select_transactions_for_block(state.pending_transactions)
      
      # Create new block
      new_block = create_new_block(
        state.blockchain_state.chain,
        selected_transactions,
        state.event_log_buffer,
        state.mining_state,
        state.rules
      )
      
      # Mine the block (simplified proof-of-work)
      mined_block = mine_block(new_block, state.mining_state)
      
      if valid_block_hash?(mined_block, state.mining_state.difficulty) do
        # Block successfully mined!
        Logger.info("💎 UFM.ApeHarmonyDaemon: Successfully mined block ##{mined_block.index}")
        
        # Update blockchain state
        updated_blockchain = add_block_to_chain(mined_block, state.blockchain_state, state.rules)
        updated_mining = update_mining_stats(state.mining_state)
        
        # Broadcast block to network
        broadcast_new_block(mined_block)
        
        %{state |
          blockchain_state: updated_blockchain,
          pending_transactions: remaining_pending,
          event_log_buffer: [],  # Clear buffer
          mining_state: updated_mining
        }
      else
        # Mining attempt failed, continue with current state
        Logger.debug("⛏️ UFM.ApeHarmonyDaemon: Mining attempt unsuccessful, continuing...")
        state
      end
    else
      state
    end
  end
  
  defp should_mine_block?(state) do
    # Mine if we have pending transactions or events in buffer
    length(state.pending_transactions) > 0 or length(state.event_log_buffer) > 0
  end
  
  defp select_transactions_for_block(pending_transactions) do
    # Select transactions based on fees and validity
    # For simplicity, take all pending transactions
    {pending_transactions, []}
  end
  
  defp create_new_block(chain, transactions, events, mining_state, rules) do
    previous_block = List.first(chain) || %{hash: "0", index: -1}
    
    %{
      index: previous_block.index + 1,
      timestamp: DateTime.utc_now(),
      previous_hash: previous_block.hash,
      transactions: transactions,
      events: events,
      nonce: 0,
      difficulty: mining_state.difficulty,
      miner: Node.self(),
      reward: Map.get(rules, :block_reward, 10.0)
    }
  end
  
  defp mine_block(block, mining_state) do
    # Simplified proof-of-work mining
    target = mining_state.current_target
    
    # Try mining with random nonce (simplified)
    nonce = :rand.uniform(1_000_000)
    block_with_nonce = %{block | nonce: nonce}
    hash = calculate_block_hash(block_with_nonce)
    
    %{block_with_nonce | hash: hash}
  end
  
  defp calculate_block_hash(block) do
    # Create deterministic hash from block data
    block_string = "#{block.index}#{block.timestamp}#{block.previous_hash}#{block.nonce}"
    :crypto.hash(:sha256, block_string) |> Base.encode16(case: :lower)
  end
  
  defp valid_block_hash?(block, difficulty) do
    # Check if hash meets difficulty requirement (simplified)
    required_zeros = String.duplicate("0", difficulty)
    String.starts_with?(block.hash, required_zeros)
  end
  
  defp calculate_mining_target(difficulty) do
    # Calculate mining target based on difficulty
    target_value = :math.pow(16, 64 - difficulty * 4)
    trunc(target_value)
  end
  
  defp add_block_to_chain(block, blockchain_state, rules) do
    updated_chain = [block | blockchain_state.chain]
    
    # Update balances based on block transactions and rewards
    updated_balances = apply_block_rewards_and_fees(block, blockchain_state.balances, rules)
    
    # Update total supply
    block_reward = Map.get(rules, :block_reward, 10.0)
    updated_supply = blockchain_state.total_supply + block_reward
    
    %{blockchain_state |
      chain: updated_chain,
      balances: updated_balances,
      total_supply: updated_supply,
      last_block_time: block.timestamp
    }
  end
  
  defp apply_block_rewards_and_fees(block, balances, rules) do
    block_reward = Map.get(rules, :block_reward, 10.0)
    
    # Award mining reward to block miner
    miner_balance = Map.get(balances, block.miner, 0.0)
    updated_balances = Map.put(balances, block.miner, miner_balance + block_reward)
    
    # Process transaction fees and transfers
    Enum.reduce(block.transactions, updated_balances, fn tx, acc_balances ->
      apply_transaction_to_balances(tx, acc_balances)
    end)
  end
  
  defp apply_transaction_to_balances(transaction, balances) do
    case transaction.type do
      :genesis_reward ->
        # Genesis transaction already handled
        balances
        
      :transfer ->
        # Transfer HARMONY tokens between nodes
        from_balance = Map.get(balances, transaction.from, 0.0)
        to_balance = Map.get(balances, transaction.to, 0.0)
        
        if from_balance >= transaction.amount + transaction.fee do
          balances
          |> Map.put(transaction.from, from_balance - transaction.amount - transaction.fee)
          |> Map.put(transaction.to, to_balance + transaction.amount)
        else
          # Insufficient balance, transaction invalid
          balances
        end
        
      _ ->
        balances
    end
  end
  
  defp update_mining_stats(mining_state) do
    %{mining_state |
      blocks_mined: mining_state.blocks_mined + 1,
      total_hash_attempts: mining_state.total_hash_attempts + 1_000_000  # Estimated
    }
  end
  
  defp broadcast_new_block(block) do
    # Broadcast block to all federation nodes
    Node.list()
    |> Enum.each(fn node ->
      try do
        send({__MODULE__, node}, {:block_received, block, Node.self()})
      rescue
        _ -> Logger.debug("Failed to broadcast block to #{node}")
      end
    end)
    
    Logger.debug("📡 UFM.ApeHarmonyDaemon: Block ##{block.index} broadcast to federation")
  end
  
  defp run_consensus_round(state) do
    Logger.debug("🗳️ UFM.ApeHarmonyDaemon: Running consensus round #{state.consensus_state.current_round + 1}")
    
    # Simplified consensus mechanism
    # In production this would implement a proper consensus algorithm like PBFT
    
    updated_consensus = %{state.consensus_state |
      current_round: state.consensus_state.current_round + 1,
      last_consensus_time: DateTime.utc_now(),
      consensus_reached: true  # Simplified
    }
    
    %{state | consensus_state: updated_consensus}
  end
  
  defp validate_incoming_blocks(state) do
    # Validate any blocks received from other nodes
    # This would implement proper block validation logic
    Logger.debug("🔍 UFM.ApeHarmonyDaemon: Validating incoming blocks")
    state
  end
  
  defp process_incoming_block(block, sender_node, state) do
    # Process a block received from another node
    if validate_block(block, state.blockchain_state) do
      Logger.info("✅ UFM.ApeHarmonyDaemon: Valid block received from #{sender_node}")
      
      # Add block to chain if valid and extends our chain
      if block.index > get_chain_height(state.blockchain_state) do
        updated_blockchain = add_block_to_chain(block, state.blockchain_state, state.rules)
        %{state | blockchain_state: updated_blockchain}
      else
        state
      end
    else
      Logger.warning("❌ UFM.ApeHarmonyDaemon: Invalid block received from #{sender_node}")
      state
    end
  end
  
  defp process_consensus_vote(vote, voter_node, state) do
    # Process consensus vote from another node
    Logger.debug("🗳️ UFM.ApeHarmonyDaemon: Processing consensus vote from #{voter_node}")
    
    updated_votes = Map.put(state.consensus_state.votes, voter_node, vote)
    updated_consensus = %{state.consensus_state | votes: updated_votes}
    
    %{state | consensus_state: updated_consensus}
  end
  
  defp validate_transaction(transaction, blockchain_state) do
    # Basic transaction validation
    cond do
      not is_map(transaction) ->
        {:error, :invalid_transaction_format}
        
      not Map.has_key?(transaction, :type) ->
        {:error, :missing_transaction_type}
        
      not Map.has_key?(transaction, :amount) ->
        {:error, :missing_amount}
        
      transaction.amount <= 0 ->
        {:error, :invalid_amount}
        
      true ->
        validated_tx = %{
          id: generate_transaction_id(),
          type: transaction.type,
          from: Map.get(transaction, :from, Node.self()),
          to: transaction.to,
          amount: transaction.amount,
          fee: Map.get(transaction, :fee, 0.1),
          timestamp: DateTime.utc_now(),
          signature: generate_transaction_signature(transaction)
        }
        {:ok, validated_tx}
    end
  end
  
  defp validate_block(block, blockchain_state) do
    # Basic block validation
    previous_block = List.first(blockchain_state.chain)
    
    cond do
      not is_map(block) -> false
      not Map.has_key?(block, :hash) -> false
      not Map.has_key?(block, :previous_hash) -> false
      previous_block && block.previous_hash != previous_block.hash -> false
      true -> true
    end
  end
  
  defp calculate_node_harmony_balance(node_id, blockchain_state) do
    Map.get(blockchain_state.balances, node_id, 0.0)
  end
  
  defp calculate_total_harmony_supply(blockchain_state) do
    blockchain_state.total_supply
  end
  
  defp get_last_block_hash(blockchain_state) do
    case List.first(blockchain_state.chain) do
      nil -> "0000000000000000000000000000000000000000000000000000000000000000"
      block -> block.hash
    end
  end
  
  defp get_chain_height(blockchain_state) do
    length(blockchain_state.chain)
  end
  
  defp discover_validator_nodes do
    # Discover nodes that can participate in consensus
    Node.list()
    |> Enum.map(fn node -> {node, %{stake: 1.0, active: true}} end)
    |> Map.new()
  end
  
  defp generate_transaction_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
  
  defp generate_transaction_signature(_transaction) do
    # Simplified signature generation
    :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
  end
  
  defp apply_ape_harmony_rule_changes(old_state, new_state) do
    # Handle configuration changes
    changes = []
    |> maybe_reschedule_mining(old_state, new_state)
    |> maybe_reschedule_consensus(old_state, new_state)
    |> maybe_reschedule_validation(old_state, new_state)
    |> maybe_update_difficulty(old_state, new_state)
    
    if length(changes) > 0 do
      Logger.info("🔄 UFM.ApeHarmonyDaemon: Applied #{length(changes)} blockchain configuration changes")
    end
    
    new_state
  end
  
  defp maybe_reschedule_mining(changes, old_state, new_state) do
    if old_state.rules[:mining_interval] != new_state.rules[:mining_interval] do
      if old_state.mining_timer, do: Process.cancel_timer(old_state.mining_timer)
      mining_timer = schedule_mining_cycle(new_state.rules)
      new_state = %{new_state | mining_timer: mining_timer}
      [:mining_rescheduled | changes]
    else
      changes
    end
  end
  
  defp maybe_reschedule_consensus(changes, old_state, new_state) do
    if old_state.rules[:consensus_interval] != new_state.rules[:consensus_interval] do
      if old_state.consensus_timer, do: Process.cancel_timer(old_state.consensus_timer)
      consensus_timer = schedule_consensus_cycle(new_state.rules)
      new_state = %{new_state | consensus_timer: consensus_timer}
      [:consensus_rescheduled | changes]
    else
      changes
    end
  end
  
  defp maybe_reschedule_validation(changes, old_state, new_state) do
    if old_state.rules[:validation_interval] != new_state.rules[:validation_interval] do
      if old_state.block_validation_timer, do: Process.cancel_timer(old_state.block_validation_timer)
      validation_timer = schedule_block_validation(new_state.rules)
      new_state = %{new_state | block_validation_timer: validation_timer}
      [:validation_rescheduled | changes]
    else
      changes
    end
  end
  
  defp maybe_update_difficulty(changes, old_state, new_state) do
    if old_state.rules[:mining_difficulty] != new_state.rules[:mining_difficulty] do
      new_difficulty = Map.get(new_state.rules, :mining_difficulty, 2)
      updated_mining = %{new_state.mining_state |
        difficulty: new_difficulty,
        current_target: calculate_mining_target(new_difficulty)
      }
      new_state = %{new_state | mining_state: updated_mining}
      Logger.info("🎯 UFM.ApeHarmonyDaemon: Mining difficulty updated to #{new_difficulty}")
      [:difficulty_updated | changes]
    else
      changes
    end
  end
end