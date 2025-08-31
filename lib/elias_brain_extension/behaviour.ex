defmodule ELIAS.BrainExtension.Behaviour do
  @moduledoc """
  Behaviour contract for ELIAS Brain Extension implementations
  
  Defines the complete API surface for the four-technology integration:
  - μTransfer: Hyperparameter scaling
  - GFlowNets: Diverse architecture discovery and content generation
  - Amortized Inference: Tractable posterior sampling
  - mLoRA: Concurrent training of thousands of adapters
  
  This behaviour ensures consistent implementation across all components
  and provides clear contracts for testing and development.
  """
  
  # User Interaction Callbacks
  @callback capture_user_input(user_id :: String.t(), input :: map()) :: 
    {:ok, response :: map()} | {:error, reason :: atom()}
    
  @callback query_knowledge_base(user_id :: String.t(), query :: String.t(), filters :: map()) ::
    {:ok, results :: list()} | {:error, reason :: atom()}
    
  @callback generate_creative_content(user_id :: String.t(), domain :: atom(), prompt :: String.t(), options :: map()) ::
    {:ok, diverse_outputs :: list()} | {:error, reason :: atom()}
  
  # Micro-LoRA Forest Management Callbacks
  @callback manage_micro_lora_forest(user_id :: String.t(), action :: atom(), params :: map()) ::
    {:ok, forest_status :: map()} | {:error, reason :: atom()}
    
  @callback train_micro_loras_concurrent(user_id :: String.t(), training_data :: map(), domains :: list()) ::
    {:ok, training_result :: map()} | {:error, reason :: atom()}
    
  @callback scale_micro_lora_with_mu_transfer(user_id :: String.t(), domain :: atom(), from_size :: integer(), to_size :: integer()) ::
    {:ok, scaling_result :: map()} | {:error, reason :: atom()}
  
  # Daemon Generation & Deployment Callbacks
  @callback generate_personalized_daemon(user_id :: String.t(), generation_options :: map()) ::
    {:ok, daemon_code :: String.t(), metadata :: map()} | {:error, reason :: atom()}
    
  @callback deploy_daemon_to_devices(user_id :: String.t(), daemon_code :: String.t(), target_devices :: list()) ::
    {:ok, deployment_status :: map()} | {:error, reason :: atom()}
    
  @callback update_daemon_incrementally(user_id :: String.t(), new_patterns :: map()) ::
    {:ok, update_result :: map()} | {:error, reason :: atom()}
  
  # Architecture Discovery Callbacks (GFlowNets)
  @callback discover_diverse_architectures(user_id :: String.t(), domain :: atom(), discovery_params :: map()) ::
    {:ok, diverse_architectures :: list()} | {:error, reason :: atom()}
    
  @callback sample_creative_ideas_gflownet(user_id :: String.t(), domain :: atom(), context :: map()) ::
    {:ok, diverse_ideas :: list()} | {:error, reason :: atom()}
  
  # Hyperparameter Transfer Callbacks (μTransfer)
  @callback setup_mu_transfer_scaling(base_config :: map(), target_config :: map()) ::
    {:ok, scaling_config :: map()} | {:error, reason :: atom()}
    
  @callback transfer_hyperparameters(domain :: atom(), proxy_hp :: map(), target_scale :: integer()) ::
    {:ok, transferred_hp :: map()} | {:error, reason :: atom()}
  
  # Amortized Inference Callbacks
  @callback sample_intractable_posterior(user_id :: String.t(), input_x :: String.t(), target_y :: String.t(), num_samples :: integer()) ::
    {:ok, posterior_samples :: list()} | {:error, reason :: atom()}
    
  @callback bayesian_model_averaging(reasoning_chains :: list(), weights :: list()) ::
    {:ok, averaged_result :: map()} | {:error, reason :: atom()}
  
  # System Monitoring Callbacks
  @callback get_system_metrics(user_id :: String.t(), metric_types :: list()) ::
    {:ok, metrics :: map()} | {:error, reason :: atom()}
    
  @callback analyze_user_patterns(user_id :: String.t(), analysis_type :: atom()) ::
    {:ok, pattern_analysis :: map()} | {:error, reason :: atom()}
  
  # Federation & Scaling Callbacks
  @callback scale_across_federation(user_id :: String.t(), scaling_params :: map()) ::
    {:ok, scaling_result :: map()} | {:error, reason :: atom()}
    
  @callback manage_corporate_sharing(organization_id :: String.t(), sharing_config :: map()) ::
    {:ok, sharing_result :: map()} | {:error, reason :: atom()}
end