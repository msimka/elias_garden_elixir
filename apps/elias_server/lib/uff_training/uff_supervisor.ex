defmodule UFFTraining.UFFSupervisor do
  @moduledoc """
  UFF Training System Supervisor
  
  RESPONSIBILITY: Supervise the complete UFF training infrastructure
  
  Supervises:
  - SessionCapture: Training data collection
  - TrainingCoordinator: Model training coordination  
  - ModelServer: UFF model inference server
  - UFMIntegration: Federation deployment management
  - MetricsCollector: Training performance tracking
  """
  
  use Supervisor
  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("UFFTraining.UFFSupervisor: Starting UFF training system")
    
    children = [
      # Core training system
      {UFFTraining.SessionCapture, []},
      {UFFTraining.TrainingCoordinator, []},
      
      # Model inference server
      {UFFTraining.ModelServer, []},
      
      # UFM federation integration
      {UFFTraining.UFMIntegration, []},
      
      # Performance tracking
      {UFFTraining.MetricsCollector, []},
      
      # Griffith manager model integration
      {UFFTraining.GriffithIntegration, []}
    ]

    opts = [strategy: :one_for_one, name: UFFTraining.UFFSupervisor]
    Supervisor.init(children, opts)
  end
  
  @doc """
  Start UFF training system with Tank Building corpus
  """
  def start_uff_training do
    Logger.info("UFFTraining: Initializing UFF training with Tank Building corpus")
    
    # Initialize all training components
    UFFTraining.TrainingCoordinator.initialize_uff_training()
    UFFTraining.SessionCapture.start_session(:stage_4, :uff_initialization, %{
      purpose: "UFF model training initialization",
      corpus: "Tank Building Stage 1-3 complete implementation"
    })
    
    Logger.info("UFFTraining: UFF training system ready")
  end
end