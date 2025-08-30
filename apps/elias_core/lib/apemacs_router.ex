defmodule Elias.ApeMacsRouter do
  @moduledoc """
  HTTP Router for ApeMacs Daemon API
  Handles REST endpoints for ApeMacs functionality
  """
  
  use Plug.Router
  require Logger

  plug Plug.Logger
  plug CORSPlug
  plug :match
  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :dispatch

  # ApeMacs API endpoints
  post "/api/claude" do
    case conn.body_params do
      %{"message" => message} ->
        result = Elias.ApeMacs.send_to_claude(message)
        send_json_response(conn, 200, result)
        
      _ ->
        send_json_response(conn, 400, %{error: "Missing 'message' parameter"})
    end
  end
  
  post "/api/terminal" do
    case conn.body_params do
      %{"command" => command} ->
        directory = Map.get(conn.body_params, "directory", ".")
        result = Elias.ApeMacs.execute_terminal_command(command, directory)
        send_json_response(conn, 200, %{result: result})
        
      _ ->
        send_json_response(conn, 400, %{error: "Missing 'command' parameter"})
    end
  end
  
  post "/api/tmux/:operation" do
    operation = String.to_atom(operation)
    args = Map.get(conn.body_params, "args", [])
    
    result = Elias.ApeMacs.tmux_operation(operation, args)
    send_json_response(conn, 200, %{result: result})
  end
  
  get "/api/clipboard" do
    result = Elias.ApeMacs.get_clipboard()
    send_json_response(conn, 200, %{clipboard: result})
  end
  
  post "/api/clipboard" do
    case conn.body_params do
      %{"content" => content} ->
        result = Elias.ApeMacs.set_clipboard(content)
        send_json_response(conn, 200, result)
        
      _ ->
        send_json_response(conn, 400, %{error: "Missing 'content' parameter"})
    end
  end
  
  get "/api/status" do
    status = %{
      daemon: "apemacs",
      status: "running",
      version: "2.0.0-elixir",
      timestamp: DateTime.utc_now(),
      uptime: System.uptime(:second)
    }
    
    send_json_response(conn, 200, status)
  end
  
  # Health check
  get "/health" do
    send_json_response(conn, 200, %{status: "healthy", service: "apemacs"})
  end
  
  # Catch-all for unknown routes
  match _ do
    send_json_response(conn, 404, %{error: "Endpoint not found"})
  end

  # Helper Functions
  defp send_json_response(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end
end