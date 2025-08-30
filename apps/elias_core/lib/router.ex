defmodule Elias.Router do
  @moduledoc """
  HTTP Router for ELIAS API endpoints
  
  Provides REST API for:
  - Rule management
  - Daemon control  
  - P2P network status
  - Claude integration
  """
  
  use Plug.Router
  require Logger

  plug Plug.Logger
  plug CORSPlug
  plug :match
  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  plug :dispatch

  # Health check
  get "/health" do
    status = %{
      status: "healthy",
      node: node(),
      connected_nodes: Node.list(),
      uptime: System.uptime(),
      version: "1.0.0"
    }
    
    send_json(conn, 200, status)
  end

  # Daemon status
  get "/daemon/status" do
    state = Elias.Daemon.get_state()
    
    status = %{
      rules_count: map_size(state.rules),
      execution_history_count: length(state.execution_history),
      last_sync: state.last_sync,
      deepseek_last_run: state.deepseek_last_run,
      node_connections: state.node_connections
    }
    
    send_json(conn, 200, status)
  end

  # Execute rule
  post "/daemon/execute" do
    case conn.body_params do
      %{"rule" => rule_name, "args" => args} ->
        case Elias.Daemon.execute_rule(rule_name, args) do
          {:ok, result} ->
            send_json(conn, 200, %{result: result})
          {:error, reason} ->
            send_json(conn, 400, %{error: inspect(reason)})
        end
      _ ->
        send_json(conn, 400, %{error: "Missing rule or args"})
    end
  end

  # Hot load rule
  post "/daemon/hot_load" do
    case conn.body_params do
      %{"key" => key, "value" => value} ->
        Elias.Daemon.hot_load_rule(key, value)
        send_json(conn, 200, %{message: "Rule loaded successfully"})
      _ ->
        send_json(conn, 400, %{error: "Missing key or value"})
    end
  end

  # Rules management
  get "/rules" do
    categories = Elias.Rules.list_categories()
    send_json(conn, 200, %{categories: categories})
  end

  get "/rules/:category" do
    rules = Elias.Rules.list_rules(category)
    send_json(conn, 200, %{rules: rules})
  end

  get "/rules/:category/:name" do
    case Elias.Rules.get_rule(category, name) do
      nil ->
        send_json(conn, 404, %{error: "Rule not found"})
      rule ->
        send_json(conn, 200, %{rule: rule})
    end
  end

  post "/rules/:category/:name" do
    case conn.body_params do
      %{"content" => content} ->
        case Elias.Rules.validate_rule(content) do
          {:ok, _type} ->
            Elias.Rules.add_rule(category, name, content)
            send_json(conn, 201, %{message: "Rule created successfully"})
          {:error, reason} ->
            send_json(conn, 400, %{error: inspect(reason)})
        end
      _ ->
        send_json(conn, 400, %{error: "Missing content"})
    end
  end

  delete "/rules/:category/:name" do
    Elias.Rules.remove_rule(category, name)
    send_json(conn, 200, %{message: "Rule deleted successfully"})
  end

  # Request Pool Management
  get "/pool/status" do
    status = Elias.RequestPool.get_status()
    send_json(conn, 200, status)
  end

  post "/pool/submit" do
    case conn.body_params do
      %{"type" => type, "payload" => payload} ->
        request_type = String.to_atom(type)
        case Elias.RequestPool.submit_request(request_type, payload) do
          {:ok, request_id} ->
            send_json(conn, 201, %{request_id: request_id, message: "Request submitted successfully"})
          {:error, reason} ->
            send_json(conn, 400, %{error: inspect(reason)})
        end
      _ ->
        send_json(conn, 400, %{error: "Missing type or payload"})
    end
  end

  # P2P network
  get "/p2p/status" do
    status = Elias.P2P.get_cluster_status()
    send_json(conn, 200, status)
  end

  post "/p2p/sync" do
    Elias.P2P.sync_rules_across_cluster()
    send_json(conn, 200, %{message: "Cluster sync initiated"})
  end

  post "/p2p/message" do
    case conn.body_params do
      %{"node" => node_name, "message" => message} ->
        node_atom = String.to_atom(node_name)
        case Elias.P2P.send_message(node_atom, message) do
          {:ok, :sent} ->
            send_json(conn, 200, %{message: "Message sent successfully"})
          {:error, reason} ->
            send_json(conn, 400, %{error: inspect(reason)})
        end
      _ ->
        send_json(conn, 400, %{error: "Missing node or message"})
    end
  end

  # Claude integration
  post "/claude/query" do
    case conn.body_params do
      %{"prompt" => prompt, "context" => context} ->
        # This would integrate with Claude API
        response = %{
          response: "This would be Claude's response via daemon",
          model: "claude-3-5-sonnet",
          tokens_used: 150,
          processed_by: node()
        }
        send_json(conn, 200, response)
      _ ->
        send_json(conn, 400, %{error: "Missing prompt"})
    end
  end

  # Sync triggers
  post "/sync/git" do
    Elias.Daemon.sync_locations()
    send_json(conn, 200, %{message: "Git sync initiated"})
  end

  post "/deepseek/optimize" do
    Elias.Rules.optimize_rules_with_deepseek()
    send_json(conn, 200, %{message: "DeepSeek optimization initiated"})
  end

  # APE HARMONY Blockchain
  get "/blockchain/status" do
    status = Elias.ApeHarmony.get_status()
    send_json(conn, 200, status)
  end

  get "/blockchain/blocks" do
    count = String.to_integer(conn.query_params["count"] || "10")
    blocks = Elias.ApeHarmony.get_recent_blocks(count)
    send_json(conn, 200, %{blocks: blocks})
  end

  get "/blockchain/contributions/:node" do
    node_name = node
    score = Elias.ApeHarmony.get_contribution_score(node_name)
    send_json(conn, 200, %{node: node_name, contribution_score: score})
  end

  # ApeMacs integration
  post "/apemacs/command" do
    case conn.body_params do
      %{"command" => command, "directory" => directory} ->
        case Elias.Daemon.execute_rule("apemacs_integration.terminal_command", [command, directory]) do
          {:ok, {output, exit_code}} ->
            send_json(conn, 200, %{output: output, exit_code: exit_code})
          {:error, reason} ->
            send_json(conn, 500, %{error: inspect(reason)})
        end
      _ ->
        send_json(conn, 400, %{error: "Missing command"})
    end
  end

  # Fallback
  match _ do
    send_json(conn, 404, %{error: "Endpoint not found"})
  end

  # Helper functions
  defp send_json(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end
end