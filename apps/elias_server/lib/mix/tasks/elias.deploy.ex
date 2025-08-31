defmodule Mix.Tasks.Elias.Deploy do
  @moduledoc """
  ELIAS Garden deployment management task.
  
  Provides comprehensive deployment management for ELIAS distributed nodes
  including Griffith server synchronization and deployment.
  
  ## Usage
  
      mix elias.deploy [COMMAND] [OPTIONS]
  
  ## Commands
  
      config      - Show deployment configuration
      status      - Show deployment status  
      sync        - Synchronize with remote server
      deploy      - Full deployment pipeline
      rollback    - Rollback deployment
      logs        - Show deployment logs
      health      - Check system health
  
  ## Options
  
      --env ENV           Set environment (dev, prod, test)
      --node NODE         Target node (griffith, gracey)
      --dry-run           Show what would be done without executing
      --force             Force deployment even with warnings
      --deploy-after-sync Deploy after successful sync
  
  ## Examples
  
      mix elias.deploy config
      mix elias.deploy status --env prod
      mix elias.deploy sync --dry-run
      mix elias.deploy deploy --env prod --deploy-after-sync
      mix elias.deploy rollback
  """
  
  use Mix.Task
  
  alias ELIAS.DeploymentManager
  
  @switches [
    env: :string,
    node: :string,
    dry_run: :boolean,
    force: :boolean,
    deploy_after_sync: :boolean,
    help: :boolean
  ]
  
  @aliases [
    e: :env,
    n: :node,
    d: :dry_run,
    f: :force,
    h: :help
  ]
  
  def run(args) do
    {opts, args} = OptionParser.parse!(args, switches: @switches, aliases: @aliases)
    
    if opts[:help] do
      show_help()
    else
      # Set environment if specified
      if env = opts[:env] do
        Mix.env(String.to_atom(env))
      end
      
      # Start the application to load configuration
      Mix.Task.run("app.start")
      
      case args do
        [] -> show_help()
        ["config"] -> show_config(opts)
        ["status"] -> show_status(opts)
        ["sync"] -> execute_sync(opts)
        ["deploy"] -> execute_deploy(opts)
        ["rollback"] -> execute_rollback(opts)
        ["logs"] -> show_logs(opts)
        ["health"] -> show_health(opts)
        [cmd] -> 
          Mix.shell().error("Unknown command: #{cmd}")
          show_help()
      end
    end
  end
  
  defp show_help do
    Mix.shell().info(@moduledoc)
  end
  
  defp show_config(opts) do
    Mix.shell().info("ELIAS Garden Deployment Configuration")
    Mix.shell().info("====================================")
    Mix.shell().info("")
    
    Mix.shell().info("Environment: #{Mix.env()}")
    Mix.shell().info("")
    
    # Griffith Configuration
    griffith_config = DeploymentManager.get_griffith_config()
    Mix.shell().info("🖥️  Griffith Server Configuration:")
    Mix.shell().info("   Host: #{Map.get(griffith_config, :host, "not configured")}")
    Mix.shell().info("   User: #{Map.get(griffith_config, :user, "not configured")}")
    Mix.shell().info("   Node Name: #{Map.get(griffith_config, :node_name, "not configured")}")
    Mix.shell().info("   Remote Path: #{Map.get(griffith_config, :remote_path, "not configured")}")
    Mix.shell().info("   SSH Port: #{Map.get(griffith_config, :ssh_port, "not configured")}")
    Mix.shell().info("")
    
    # Sync Configuration
    sync_config = DeploymentManager.get_sync_config()
    Mix.shell().info("🔄 Sync Configuration:")
    
    rsync_options = Map.get(sync_config, :rsync_options, [])
    Mix.shell().info("   Rsync Options: #{Enum.join(rsync_options, " ")}")
    
    exclude_patterns = Map.get(sync_config, :exclude_patterns, [])
    Mix.shell().info("   Exclude Patterns: #{Enum.join(exclude_patterns, ", ")}")
    Mix.shell().info("")
    
    # Deployment Configuration  
    deployment_config = DeploymentManager.get_deployment_config()
    stages = Map.get(deployment_config, :stages, [])
    Mix.shell().info("🚀 Deployment Stages: #{Enum.join(stages, " → ")}")
    Mix.shell().info("")
    
    # Configuration Validation
    case DeploymentManager.validate_config() do
      {:ok, message} -> 
        Mix.shell().info("✅ Configuration Status: #{message}")
      {:error, reason} -> 
        Mix.shell().error("❌ Configuration Error: #{reason}")
    end
  end
  
  defp show_status(opts) do
    Mix.shell().info("ELIAS Garden Deployment Status")
    Mix.shell().info("==============================")
    Mix.shell().info("")
    
    status = DeploymentManager.deployment_status()
    
    Mix.shell().info("📊 Current Status:")
    Mix.shell().info("   Environment: #{status.environment}")
    Mix.shell().info("   Griffith Configured: #{format_boolean(status.griffith_configured)}")
    Mix.shell().info("   Configuration Valid: #{format_boolean(status.configuration_valid)}")
    Mix.shell().info("   Deployment Ready: #{format_boolean(status.deployment_ready)}")
    Mix.shell().info("")
    
    Mix.shell().info("🏷️  Node Information:")
    Mix.shell().info("   Node Name: #{status.node_name || "not configured"}")
    Mix.shell().info("   Host: #{status.host || "not configured"}")
    Mix.shell().info("")
    
    if status.last_sync do
      formatted_time = format_datetime(status.last_sync)
      Mix.shell().info("🕒 Last Sync: #{formatted_time}")
    else
      Mix.shell().info("🕒 Last Sync: never")
    end
    
    Mix.shell().info("")
    Mix.shell().info("📋 Deployment Stages:")
    Enum.with_index(status.deployment_stages, 1)
    |> Enum.each(fn {stage, index} ->
      Mix.shell().info("   #{index}. #{stage}")
    end)
  end
  
  defp execute_sync(opts) do
    Mix.shell().info("🔄 Starting ELIAS Garden Sync")
    Mix.shell().info("=============================")
    Mix.shell().info("")
    
    if opts[:dry_run] do
      Mix.shell().info("🧪 DRY RUN MODE - No actual changes will be made")
      Mix.shell().info("")
    end
    
    # Prepare deployment
    case DeploymentManager.prepare_deployment() do
      {:ok, message} ->
        Mix.shell().info("✅ Preparation: #{message}")
        
        # Execute sync
        sync_options = [
          dry_run: opts[:dry_run] || false,
          deploy_after_sync: opts[:deploy_after_sync] || false
        ]
        
        execute_sync_deployment(sync_options, opts)
        
      {:error, reason} ->
        Mix.shell().error("❌ Preparation failed: #{reason}")
        unless opts[:force] do
          Mix.shell().error("Use --force to proceed anyway")
        else
          # Force execution despite preparation failure
          sync_options = [
            dry_run: opts[:dry_run] || false,
            deploy_after_sync: opts[:deploy_after_sync] || false
          ]
          execute_sync_deployment(sync_options, opts)
        end
    end
  end
  
  defp execute_sync_deployment(sync_options, opts) do
    
    case DeploymentManager.execute_deployment(sync_options) do
      {:ok, message} ->
        Mix.shell().info("✅ Sync completed: #{message}")
        
        if not opts[:dry_run] do
          Mix.shell().info("")
          Mix.shell().info("🎯 Next Steps:")
          Mix.shell().info("   1. Check sync status: mix elias.deploy status")
          Mix.shell().info("   2. View logs: mix elias.deploy logs")
          if not opts[:deploy_after_sync] do
            Mix.shell().info("   3. Deploy if needed: mix elias.deploy deploy --env #{Mix.env()}")
          end
        end
      {:error, reason} ->
        Mix.shell().error("❌ Sync failed: #{reason}")
    end
  end
  
  defp execute_deploy(opts) do
    Mix.shell().info("🚀 Starting ELIAS Garden Deployment")
    Mix.shell().info("===================================")
    Mix.shell().info("")
    
    if opts[:dry_run] do
      Mix.shell().info("🧪 DRY RUN MODE - No actual deployment will occur")
      Mix.shell().info("")
    end
    
    deploy_options = [
      dry_run: opts[:dry_run] || false,
      deploy_after_sync: true
    ]
    
    case DeploymentManager.execute_deployment(deploy_options) do
      {:ok, message} ->
        Mix.shell().info("✅ Deployment completed: #{message}")
        
        if not opts[:dry_run] do
          Mix.shell().info("")
          Mix.shell().info("🎉 Deployment successful!")
          Mix.shell().info("   Check status: mix elias.deploy status")
          Mix.shell().info("   View health: mix elias.deploy health")
          Mix.shell().info("   Monitor logs: mix elias.deploy logs")
        end
      {:error, reason} ->
        Mix.shell().error("❌ Deployment failed: #{reason}")
        Mix.shell().error("   Check logs: mix elias.deploy logs")
        Mix.shell().error("   Consider rollback: mix elias.deploy rollback")
    end
  end
  
  defp execute_rollback(opts) do
    Mix.shell().info("🔄 Starting Deployment Rollback")
    Mix.shell().info("===============================")
    Mix.shell().info("")
    
    if opts[:dry_run] do
      Mix.shell().info("🧪 DRY RUN MODE - No actual rollback will occur")
      Mix.shell().info("")
    end
    
    unless opts[:force] do
      response = Mix.shell().prompt("Are you sure you want to rollback? (y/N)")
      if String.downcase(response) in ["y", "yes"] do
        # Continue with rollback
        execute_rollback_process(opts)
      else
        Mix.shell().info("Rollback cancelled")
      end
    else
      execute_rollback_process(opts)
    end
  end
  
  defp execute_rollback_process(opts) do
    
    case DeploymentManager.rollback_deployment() do
      {:ok, message} ->
        Mix.shell().info("✅ Rollback completed: #{message}")
      {:error, reason} ->
        Mix.shell().error("❌ Rollback failed: #{reason}")
    end
  end
  
  defp show_logs(opts) do
    Mix.shell().info("ELIAS Garden Deployment Logs")
    Mix.shell().info("============================")
    Mix.shell().info("")
    
    logs = DeploymentManager.get_deployment_logs()
    
    Mix.shell().info("📊 Recent Deployments:")
    Enum.each(logs.recent_deployments, fn deployment ->
      status_icon = case deployment.status do
        :success -> "✅"
        :failed -> "❌"
        _ -> "🔄"
      end
      
      formatted_time = format_datetime(deployment.timestamp)
      
      Mix.shell().info("   #{status_icon} #{deployment.id} (#{deployment.environment}) - #{formatted_time} - #{deployment.duration_seconds}s")
    end)
    
    Mix.shell().info("")
    Mix.shell().info("🏥 System Health:")
    health = logs.system_health
    Mix.shell().info("   CPU Usage: #{health.cpu_usage}%")
    Mix.shell().info("   Memory Usage: #{health.memory_usage}%")
    Mix.shell().info("   Disk Usage: #{health.disk_usage}%")
    Mix.shell().info("   Network Status: #{health.network_status}")
    Mix.shell().info("   Service Status: #{health.service_status}")
  end
  
  defp show_health(opts) do
    Mix.shell().info("ELIAS Garden System Health")
    Mix.shell().info("==========================")
    Mix.shell().info("")
    
    logs = DeploymentManager.get_deployment_logs()
    health = logs.system_health
    
    # Overall health assessment
    health_score = calculate_health_score(health)
    health_status = case health_score do
      score when score >= 90 -> {"🟢", "Excellent"}
      score when score >= 75 -> {"🟡", "Good"} 
      score when score >= 50 -> {"🟠", "Fair"}
      _ -> {"🔴", "Poor"}
    end
    
    {icon, status_text} = health_status
    Mix.shell().info("#{icon} Overall Health: #{status_text} (#{health_score}%)")
    Mix.shell().info("")
    
    Mix.shell().info("📊 System Metrics:")
    Mix.shell().info("   CPU Usage: #{format_metric(health.cpu_usage, 80)}%")
    Mix.shell().info("   Memory Usage: #{format_metric(health.memory_usage, 85)}%")
    Mix.shell().info("   Disk Usage: #{format_metric(health.disk_usage, 90)}%")
    Mix.shell().info("   Network Status: #{format_status(health.network_status)}")
    Mix.shell().info("   Service Status: #{format_status(health.service_status)}")
    Mix.shell().info("")
    
    formatted_time = format_datetime(health.last_health_check)
    Mix.shell().info("🕒 Last Health Check: #{formatted_time}")
    
    # Health recommendations
    recommendations = generate_health_recommendations(health)
    if not Enum.empty?(recommendations) do
      Mix.shell().info("")
      Mix.shell().info("💡 Recommendations:")
      Enum.each(recommendations, fn rec ->
        Mix.shell().info("   • #{rec}")
      end)
    end
  end
  
  # Helper functions
  
  defp format_boolean(true), do: "✅ Yes"
  defp format_boolean(false), do: "❌ No"
  
  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end
  defp format_datetime(_), do: "unknown"
  
  defp format_metric(value, threshold) when value > threshold do
    "🔴 #{value}"
  end
  defp format_metric(value, _threshold) do
    "🟢 #{value}"
  end
  
  defp format_status(:healthy), do: "🟢 Healthy"
  defp format_status(:running), do: "🟢 Running"  
  defp format_status(:degraded), do: "🟡 Degraded"
  defp format_status(:down), do: "🔴 Down"
  defp format_status(status), do: "⚪ #{status}"
  
  defp calculate_health_score(health) do
    cpu_score = max(0, 100 - health.cpu_usage)
    memory_score = max(0, 100 - health.memory_usage)  
    disk_score = max(0, 100 - health.disk_usage)
    
    network_score = if health.network_status == :healthy, do: 100, else: 0
    service_score = if health.service_status == :running, do: 100, else: 0
    
    scores = [cpu_score, memory_score, disk_score, network_score, service_score]
    round(Enum.sum(scores) / length(scores))
  end
  
  defp generate_health_recommendations(health) do
    recommendations = []
    
    recommendations = if health.cpu_usage > 80 do
      ["Consider CPU optimization or scaling" | recommendations]
    else
      recommendations
    end
    
    recommendations = if health.memory_usage > 85 do
      ["Monitor memory usage and consider increasing available memory" | recommendations]
    else
      recommendations
    end
    
    recommendations = if health.disk_usage > 90 do
      ["Disk usage high - clean up old files or increase storage" | recommendations] 
    else
      recommendations
    end
    
    recommendations = if health.network_status != :healthy do
      ["Check network connectivity and configuration" | recommendations]
    else
      recommendations
    end
    
    recommendations = if health.service_status != :running do
      ["Service not running - check service status and logs" | recommendations]
    else
      recommendations
    end
    
    recommendations
  end
end