defmodule EliasServer.TaskManagerCLI do
  @moduledoc """
  Command Line Interface for ELIAS Task Manager
  
  Provides Windows Task Manager-like interface in terminal with:
  - Real-time process monitoring
  - Interactive process management
  - System resource visualization
  - Manager model control
  """
  
  require Logger
  
  @refresh_commands ["r", "refresh"]
  @quit_commands ["q", "quit", "exit"]
  @help_commands ["h", "help", "?"]
  
  def start do
    IO.puts("\n🖥️  Starting ELIAS Federation Task Manager...")
    IO.puts("Loading system data...\n")
    
    # Ensure task manager is running
    {:ok, _pid} = EliasServer.EliasTaskManager.start_link()
    
    main_loop()
  end
  
  defp main_loop do
    display_task_manager_screen()
    handle_user_input()
  end
  
  defp display_task_manager_screen do
    clear_screen()
    display_header()
    display_system_overview()
    display_process_list()
    display_manager_status()
    display_training_status()
    display_commands()
  end
  
  defp clear_screen do
    IO.write("\e[2J\e[H")  # ANSI clear screen and move cursor to top
  end
  
  defp display_header do
    IO.puts(String.duplicate("=", 100))
    IO.puts("🖥️  ELIAS FEDERATION TASK MANAGER                                    #{format_timestamp()}")
    IO.puts(String.duplicate("=", 100))
  end
  
  defp display_system_overview do
    case EliasServer.EliasTaskManager.get_system_overview() do
      overview ->
        IO.puts("📊 SYSTEM OVERVIEW")
        IO.puts(String.duplicate("-", 50))
        IO.puts("Processes: #{overview.total_processes} total | #{overview.running_processes} running | #{overview.training_processes} training")
        IO.puts("Managers:  7 DeepSeek models (UFM,UCM,URM,ULM,UIM,UAM,UDM) | #{count_healthy_managers(overview.manager_status)} healthy")
        IO.puts("Training:  #{overview.training_schedule.weekly_capacity} | Kaggle: #{overview.training_schedule.kaggle_hours_used} | SageMaker: #{overview.training_schedule.sagemaker_hours_used}")
        
        resources = overview.system_resources
        IO.puts("Resources: CPU #{resources.cpu_usage_percent}% | Memory #{resources.memory_usage_mb}MB | GPU #{resources.gpu_usage_percent}% | Net #{resources.network_mb_per_sec}MB/s")
    end
    
    IO.puts("")
  end
  
  defp display_process_list do
    case EliasServer.EliasTaskManager.get_all_processes() do
      processes ->
        IO.puts("🔄 ACTIVE PROCESSES")
        IO.puts(String.duplicate("-", 100))
        IO.puts("PID                     | NAME                        | TYPE        | STATUS   | CPU%  | MEM(MB) | SYSTEM")
        IO.puts(String.duplicate("-", 100))
        
        processes
        |> Enum.take(10)  # Show top 10 processes
        |> Enum.each(fn process ->
          pid_str = format_pid(process.pid)
          name_str = format_name(process.name)
          type_str = format_type(process.type)
          status_str = format_status(process.status)
          cpu_str = format_cpu(process.cpu_percent)
          mem_str = format_memory(process.memory_mb)
          system_str = format_system(process.parent_system)
          
          IO.puts("#{pid_str} | #{name_str} | #{type_str} | #{status_str} | #{cpu_str} | #{mem_str} | #{system_str}")
        end)
        
        if length(processes) > 10 do
          IO.puts("... and #{length(processes) - 10} more processes")
        end
    end
    
    IO.puts("")
  end
  
  defp display_manager_status do
    IO.puts("🧠 MANAGER MODELS STATUS")
    IO.puts(String.duplicate("-", 70))
    
    managers = [:ufm, :ucm, :urm, :ulm, :uim, :uam, :udm]
    
    Enum.each(managers, fn manager ->
      case EliasServer.EliasTaskManager.get_manager_details(manager) do
        details ->
          status_icon = if details.status == :healthy, do: "✅", else: "❌"
          manager_name = String.upcase("#{manager}")
          specialization = String.slice(details.specialization, 0, 35)
          cpu = details.total_cpu
          memory = details.total_memory
          
          IO.puts("#{status_icon} #{pad_right(manager_name, 4)} | #{pad_right(specialization, 35)} | CPU: #{pad_left("#{cpu}%", 4)} | MEM: #{memory}MB")
      end
    end)
    
    IO.puts("")
  end
  
  defp display_training_status do
    IO.puts("🚀 TRAINING STATUS")
    IO.puts(String.duplicate("-", 50))
    
    # Show current training schedule
    day_of_week = Date.day_of_week(Date.utc_today())
    days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    managers = ["UFM", "UCM", "URM", "ULM", "UIM", "UAM", "UDM"]
    
    current_day = Enum.at(days, day_of_week - 1)
    current_manager = Enum.at(managers, day_of_week - 1)
    
    IO.puts("Today (#{current_day}): Kaggle Main UFF (4h) + SageMaker #{current_manager} (4h) = 8h total")
    IO.puts("This Week: 58h distributed training capacity")
    
    # Show active training jobs
    training_processes = EliasServer.EliasTaskManager.get_all_processes()
    |> Enum.filter(& &1.type == :training)
    
    if length(training_processes) > 0 do
      IO.puts("Active Training Jobs:")
      Enum.each(training_processes, fn process ->
        duration = format_duration(process.uptime_seconds)
        IO.puts("  • #{process.name} (#{process.parent_system}) - #{duration}")
      end)
    else
      IO.puts("No active training jobs")
    end
    
    IO.puts("")
  end
  
  defp display_commands do
    IO.puts("COMMANDS: [R]efresh | [K]ill process | [M]anager details | [T]raining control | [H]elp | [Q]uit")
    IO.write("elias_task_manager> ")
  end
  
  defp handle_user_input do
    case IO.gets("") do
      :eof -> 
        IO.puts("\n👋 Closing ELIAS Task Manager...")
        :ok
      input when is_binary(input) ->
        case String.trim(input) |> String.downcase() do
          cmd when cmd in @refresh_commands ->
            main_loop()
            
          cmd when cmd in @quit_commands ->
            IO.puts("\n👋 Closing ELIAS Task Manager...")
            :ok
            
          cmd when cmd in @help_commands ->
            display_help()
            wait_for_enter()
            main_loop()
            
          "k" <> rest ->
            handle_kill_command(String.trim(rest))
            main_loop()
            
          "m" <> rest ->
            handle_manager_command(String.trim(rest))
            main_loop()
            
          "t" ->
            display_training_control()
            wait_for_enter()
            main_loop()
            
          "" ->
            # Enter pressed - refresh
            main_loop()
            
          unknown ->
            IO.puts("Unknown command: #{unknown}. Type 'h' for help.")
            :timer.sleep(1000)
            main_loop()
        end
    end
  end
  
  defp handle_kill_command("") do
    IO.puts("Usage: k <pid> - Kill process by PID")
    :timer.sleep(1500)
  end
  
  defp handle_kill_command(pid_str) do
    case EliasServer.EliasTaskManager.kill_process(pid_str) do
      :ok ->
        IO.puts("✅ Process #{pid_str} terminated")
        
      {:error, :process_not_found} ->
        IO.puts("❌ Process #{pid_str} not found")
        
      {:error, reason} ->
        IO.puts("❌ Failed to kill process: #{reason}")
    end
    
    :timer.sleep(1500)
  end
  
  defp handle_manager_command("") do
    IO.puts("Usage: m <manager> - Show manager details (ufm, ucm, urm, ulm, uim, uam, udm)")
    :timer.sleep(1500)
  end
  
  defp handle_manager_command(manager_str) do
    manager = String.to_atom(manager_str)
    
    case EliasServer.EliasTaskManager.get_manager_details(manager) do
      details ->
        IO.puts("\n🧠 #{String.upcase("#{manager}")} MANAGER DETAILS")
        IO.puts(String.duplicate("=", 50))
        IO.puts("Specialization: #{details.specialization}")
        IO.puts("Model Path: #{details.model_path}")
        IO.puts("Status: #{details.status}")
        IO.puts("Total CPU: #{details.total_cpu}%")
        IO.puts("Total Memory: #{details.total_memory}MB")
        IO.puts("Processes: #{length(details.processes)}")
        
        if length(details.processes) > 0 do
          IO.puts("\nActive Processes:")
          Enum.each(details.processes, fn process ->
            IO.puts("  • #{process.name} - #{process.status}")
          end)
        end
    end
    
    wait_for_enter()
  end
  
  defp display_training_control do
    IO.puts("\n🚀 TRAINING CONTROL PANEL")
    IO.puts(String.duplicate("=", 50))
    IO.puts("Current Schedule (58h/week distributed):")
    IO.puts("  Monday:    Kaggle Main UFF (4h) + SageMaker UFM (4h)")
    IO.puts("  Tuesday:   Kaggle Main UFF (4h) + SageMaker UCM (4h)")
    IO.puts("  Wednesday: Kaggle Main UFF (4h) + SageMaker URM (4h)")
    IO.puts("  Thursday:  Kaggle Main UFF (4h) + SageMaker ULM (4h)")
    IO.puts("  Friday:    Kaggle Main UFF (4h) + SageMaker UIM (4h)")
    IO.puts("  Saturday:  Kaggle Main UFF (4h) + SageMaker UAM (4h)")
    IO.puts("  Sunday:    Kaggle Main UFF (6h) + SageMaker UDM (4h)")
    IO.puts("\nTraining Commands:")
    IO.puts("  ./scripts/cloud_training_orchestrator.sh weekly")
    IO.puts("  ./scripts/cloud_training_orchestrator.sh monitor")
    IO.puts("  ./scripts/cloud_training_orchestrator.sh sync")
  end
  
  defp display_help do
    IO.puts("\n📖 ELIAS TASK MANAGER HELP")
    IO.puts(String.duplicate("=", 40))
    IO.puts("Commands:")
    IO.puts("  r, refresh    - Refresh all system data")
    IO.puts("  k <pid>       - Kill process by PID")
    IO.puts("  m <manager>   - Show manager details (ufm,ucm,urm,ulm,uim,uam,udm)")
    IO.puts("  t             - Show training control panel")
    IO.puts("  h, help       - Show this help")
    IO.puts("  q, quit       - Exit task manager")
    IO.puts("  <enter>       - Refresh screen")
    IO.puts("\nManager Types:")
    IO.puts("  UFM - Federation orchestration")
    IO.puts("  UCM - Content processing")
    IO.puts("  URM - Resource optimization")
    IO.puts("  ULM - Learning adaptation") 
    IO.puts("  UIM - Interface design")
    IO.puts("  UAM - Creative generation")
    IO.puts("  UDM - Universal deployment orchestration")
  end
  
  defp wait_for_enter do
    IO.gets("\nPress Enter to continue...")
  end
  
  # Formatting Functions
  
  defp format_timestamp do
    DateTime.utc_now()
    |> DateTime.to_string()
    |> String.slice(0, 19)
  end
  
  defp format_pid(pid) when is_pid(pid), do: pid |> :erlang.pid_to_list() |> to_string() |> pad_right(22)
  defp format_pid(pid), do: to_string(pid) |> pad_right(22)
  
  defp format_name(name), do: name |> to_string() |> String.slice(0, 27) |> pad_right(27)
  defp format_type(type), do: type |> to_string() |> String.slice(0, 11) |> pad_right(11)
  defp format_status(status), do: status |> to_string() |> String.slice(0, 8) |> pad_right(8)
  defp format_cpu(nil), do: "  N/A"
  defp format_cpu(cpu), do: "#{cpu}%" |> pad_left(5)
  defp format_memory(nil), do: "    N/A"
  defp format_memory(mem), do: "#{mem}" |> pad_left(7)
  defp format_system(system), do: system |> to_string() |> String.slice(0, 10) |> pad_right(10)
  
  defp format_duration(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    "#{hours}h #{minutes}m"
  end
  
  defp pad_right(str, width), do: String.pad_trailing(str, width)
  defp pad_left(str, width), do: String.pad_leading(str, width)
  
  defp count_healthy_managers(manager_status) do
    manager_status
    |> Map.values()
    |> Enum.count(& &1 == :healthy)
  end
end