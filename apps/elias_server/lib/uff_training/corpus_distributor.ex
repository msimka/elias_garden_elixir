defmodule UFFTraining.CorpusDistributor do
  @moduledoc """
  Training Data Distribution for Manager Specialization
  
  Strategy: Full corpus + domain-specific augmentation
  - All models get 100% Tank Building corpus (base methodology)
  - Each manager gets 30-50% additional domain-specific data
  - ULM generates synthetic episodes for specialized training
  """
  
  require Logger
  
  @manager_domains %{
    ufm: %{
      focus: "federation_orchestration",
      augmentation_patterns: [
        "Node federation and load balancing",
        "Cross-manager coordination patterns",
        "Rollup node orchestration", 
        "Federation health monitoring"
      ],
      synthetic_ratio: 0.3
    },
    ucm: %{
      focus: "content_processing", 
      augmentation_patterns: [
        "Multi-format content processing",
        "Pipeline optimization patterns",
        "Content transformation logic",
        "Format-specific extraction algorithms"
      ],
      synthetic_ratio: 0.4
    },
    urm: %{
      focus: "resource_optimization",
      augmentation_patterns: [
        "GPU memory optimization",
        "Process scheduling algorithms", 
        "Resource allocation strategies",
        "Performance monitoring patterns"
      ],
      synthetic_ratio: 0.3
    },
    ulm: %{
      focus: "learning_adaptation",
      augmentation_patterns: [
        "Tank Building methodology refinement",
        "Component quality assessment",
        "Learning pattern recognition", 
        "Adaptive improvement strategies"
      ],
      synthetic_ratio: 0.5  # ULM generates the most synthetic data
    },
    uim: %{
      focus: "interface_design",
      augmentation_patterns: [
        "CLI and API design patterns",
        "User interaction optimization",
        "Interface component generation",
        "Developer experience patterns"
      ],
      synthetic_ratio: 0.3
    },
    uam: %{
      focus: "creative_generation", 
      augmentation_patterns: [
        "Documentation and content creation",
        "Brand voice and messaging",
        "Creative component generation",
        "Artistic design patterns"
      ],
      synthetic_ratio: 0.4
    }
  }
  
  def distribute_training_corpus(base_corpus_path, output_dir) do
    Logger.info("Distributing Tank Building corpus for manager specialization")
    
    # Load base corpus
    {:ok, base_corpus} = load_base_corpus(base_corpus_path)
    
    # Create main UFF corpus (full corpus)
    main_corpus_path = Path.join(output_dir, "main_uff_corpus.jsonl")
    write_corpus(main_corpus_path, base_corpus)
    
    # Create manager-specific corpora
    manager_corpora = Enum.map(@manager_domains, fn {manager, domain_config} ->
      create_manager_corpus(manager, domain_config, base_corpus, output_dir)
    end)
    
    %{
      main_corpus: main_corpus_path,
      manager_corpora: Map.new(manager_corpora),
      total_episodes: length(base_corpus),
      distribution_complete: true
    }
  end
  
  defp load_base_corpus(corpus_path) do
    case File.read(corpus_path) do
      {:ok, content} ->
        # Parse JSONL format
        episodes = content
        |> String.split("\n", trim: true)
        |> Enum.map(&Jason.decode!/1)
        
        {:ok, episodes}
        
      {:error, reason} ->
        {:error, "Failed to load corpus: #{reason}"}
    end
  end
  
  defp create_manager_corpus(manager, domain_config, base_corpus, output_dir) do
    Logger.info("Creating specialized corpus for #{manager}")
    
    # Filter base corpus for manager-relevant episodes
    relevant_episodes = filter_episodes_for_manager(base_corpus, manager)
    
    # Generate synthetic episodes using domain patterns
    synthetic_episodes = generate_synthetic_episodes(
      manager, 
      domain_config.augmentation_patterns,
      round(length(base_corpus) * domain_config.synthetic_ratio)
    )
    
    # Combine full base corpus + relevant focus + synthetics
    manager_corpus = base_corpus ++ relevant_episodes ++ synthetic_episodes
    
    # Write manager-specific corpus
    corpus_path = Path.join(output_dir, "#{manager}_specialized_corpus.jsonl")
    write_corpus(corpus_path, manager_corpus)
    
    {manager, %{
      corpus_path: corpus_path,
      total_episodes: length(manager_corpus),
      base_episodes: length(base_corpus),
      focused_episodes: length(relevant_episodes),
      synthetic_episodes: length(synthetic_episodes),
      specialization_ratio: domain_config.synthetic_ratio
    }}
  end
  
  defp filter_episodes_for_manager(base_corpus, manager) do
    # Filter episodes that are most relevant to manager domain
    base_corpus
    |> Enum.filter(fn episode ->
      episode_relevance = calculate_manager_relevance(episode, manager)
      episode_relevance > 0.7  # High relevance threshold
    end)
  end
  
  defp calculate_manager_relevance(episode, manager) do
    manager_keywords = get_manager_keywords(manager)
    episode_text = "#{episode["component_code"]} #{episode["architectural_decisions"]}"
    
    keyword_matches = Enum.count(manager_keywords, fn keyword ->
      String.contains?(String.downcase(episode_text), String.downcase(keyword))
    end)
    
    keyword_matches / length(manager_keywords)
  end
  
  defp get_manager_keywords(manager) do
    case manager do
      :ufm -> ["federation", "node", "load", "balance", "coordinate", "distribute"]
      :ucm -> ["content", "format", "extract", "process", "pipeline", "convert"] 
      :urm -> ["resource", "memory", "gpu", "optimize", "schedule", "allocate"]
      :ulm -> ["learn", "adapt", "improve", "quality", "methodology", "assess"]
      :uim -> ["interface", "cli", "api", "user", "experience", "interaction"]
      :uam -> ["creative", "content", "brand", "document", "artistic", "design"]
    end
  end
  
  defp generate_synthetic_episodes(manager, patterns, count) do
    Logger.info("Generating #{count} synthetic episodes for #{manager}")
    
    Enum.map(1..count, fn i ->
      pattern = Enum.random(patterns)
      
      %{
        "session_id" => "synthetic_#{manager}_#{i}",
        "tank_building_stage" => Enum.random(["stage_1", "stage_2", "stage_3", "stage_4"]),
        "component_code" => generate_synthetic_component(manager, pattern),
        "claude_feedback" => generate_synthetic_feedback(manager, pattern),
        "reward_signals" => %{
          "total_reward" => :rand.uniform() * 0.3 + 0.7,  # 0.7-1.0 range
          "component_atomicity_score" => :rand.uniform() * 0.2 + 0.8,
          "tiki_compliance_score" => :rand.uniform() * 0.2 + 0.8
        },
        "created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "synthetic" => true,
        "manager_focus" => manager,
        "augmentation_pattern" => pattern
      }
    end)
  end
  
  defp generate_synthetic_component(manager, pattern) do
    base_template = get_component_template(manager)
    
    """
    # Synthetic #{String.upcase("#{manager}")} Component: #{pattern}
    # Generated for specialized training
    
    #{base_template}
    
    # Domain-specific implementation for #{pattern}
    defp #{String.downcase(String.replace(pattern, " ", "_"))}(input) do
      # Tank Building Stage implementation
      input
      |> validate_atomicity()
      |> process_#{manager}_specific()
      |> verify_result()
    end
    """
  end
  
  defp get_component_template(manager) do
    case manager do
      :ufm -> "defmodule FederationComponent do\n  def coordinate(nodes), do: balance_load(nodes)\nend"
      :ucm -> "defmodule ContentComponent do\n  def process(content, format), do: extract_data(content, format)\nend"
      :urm -> "defmodule ResourceComponent do\n  def optimize(resources), do: allocate_efficiently(resources)\nend"
      :ulm -> "defmodule LearningComponent do\n  def adapt(patterns), do: improve_methodology(patterns)\nend"
      :uim -> "defmodule InterfaceComponent do\n  def design(requirements), do: create_user_friendly(requirements)\nend"
      :uam -> "defmodule CreativeComponent do\n  def generate(brief), do: create_artistic_content(brief)\nend"
    end
  end
  
  defp generate_synthetic_feedback(manager, pattern) do
    [
      %{
        "type" => "architectural_review",
        "feedback" => "#{pattern} implementation follows Tank Building principles well for #{manager} domain",
        "score" => :rand.uniform() * 0.2 + 0.8
      }
    ]
  end
  
  defp write_corpus(file_path, episodes) do
    # Ensure output directory exists
    output_dir = Path.dirname(file_path)
    File.mkdir_p!(output_dir)
    
    # Write episodes as JSONL
    jsonl_content = episodes
    |> Enum.map(&Jason.encode!/1)
    |> Enum.join("\n")
    
    File.write!(file_path, jsonl_content)
    Logger.info("Wrote #{length(episodes)} episodes to #{file_path}")
  end
end