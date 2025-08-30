defmodule EliasContent.BlogGenerator do
  @moduledoc """
  Content automation for generating blog posts from truisms
  Following architect guidance for ULM-driven content creation
  
  Usage:
    mix elias.content_gen --truism "Tank Building: Brute force first, elegant second" --channel blog
  """
  
  @doc """
  Generate blog post from a truism, following Tank Building methodology
  """
  def generate_from_truism(truism, channel \\ :blog, opts \\ []) do
    case validate_truism(truism) do
      {:ok, validated_truism} ->
        blog_content = create_blog_structure(validated_truism, opts)
        {:ok, blog_content}
        
      {:error, reason} ->
        {:error, "Truism validation failed: #{reason}"}
    end
  end
  
  @doc """
  Validate truism against ELIAS brand standards
  """
  def validate_truism(truism) do
    cond do
      String.length(truism) > 200 ->
        {:error, "Truism too long (max 200 chars for blog generation)"}
        
      not (String.contains?(truism, ["Tank Building", "ELIAS", "Stage", "manager"]) or
           has_development_keywords?(truism)) ->
        {:error, "Truism doesn't align with ELIAS methodology or development philosophy"}
        
      true ->
        {:ok, %{
          text: truism,
          category: categorize_truism(truism),
          t_shirt_ready: is_t_shirt_ready?(truism),
          tank_building_stage: infer_tank_building_stage(truism)
        }}
    end
  end
  
  # Private helper functions
  
  defp create_blog_structure(validated_truism, opts) do
    template = """
    # #{generate_title(validated_truism)}
    
    ## The Problem
    #{generate_problem_hook(validated_truism)}
    
    ## The Tank Building Principle  
    > "#{validated_truism.text}"
    
    #{explain_principle(validated_truism)}
    
    ## ELIAS Implementation Example
    #{generate_elias_example(validated_truism)}
    
    ## Code Example
    ```elixir
    #{generate_code_example(validated_truism)}
    ```
    
    ## Results and Metrics
    #{generate_results_section(validated_truism)}
    
    ## Next Steps in Your Development
    #{generate_next_steps(validated_truism)}
    
    ## Key Takeaway
    #{generate_takeaway(validated_truism)}
    
    ---
    
    *Part of the [Tank Building Methodology Series](../tank_building_methodology_series.md) - demonstrating systematic software development through ELIAS implementation.*
    
    **Tags**: #{generate_tags(validated_truism)}
    **Channels**: Blog, #{if opts[:youtube], do: "YouTube follow-up, ", else: ""}#{if opts[:podcast], do: "Podcast discussion", else: ""}
    """
    
    %{
      title: generate_title(validated_truism),
      content: template,
      metadata: generate_metadata(validated_truism, opts),
      filename: generate_filename(validated_truism)
    }
  end
  
  defp categorize_truism(truism) do
    cond do
      String.contains?(truism, ["Tank Building", "Stage", "iteration"]) ->
        :tank_building_methodology
        
      String.contains?(truism, ["manager", "distributed", "ELIAS"]) ->
        :ai_distributed_systems
        
      String.contains?(truism, ["quality", "test", "documentation"]) ->
        :quality_learning
        
      String.contains?(truism, ["innovation", "system", "architecture"]) ->
        :innovation_methodology
        
      true ->
        :general_development
    end
  end
  
  defp is_t_shirt_ready?(truism) do
    # T-shirt ready: concise, impactful, conversation starter
    String.length(truism) <= 50 and 
    not String.contains?(truism, ["very", "really", "actually"]) and
    String.match?(truism, ~r/^[A-Z].*[^.]$/)  # Starts capitalized, no trailing period
  end
  
  defp infer_tank_building_stage(truism) do
    cond do
      String.contains?(truism, ["work", "functional", "first"]) -> 1
      String.contains?(truism, ["better", "extend", "improve"]) -> 2  
      String.contains?(truism, ["perfect", "elegant", "optimize"]) -> 3
      String.contains?(truism, ["again", "iterate", "refine"]) -> 4
      true -> 1  # Default to Stage 1
    end
  end
  
  defp has_development_keywords?(truism) do
    keywords = ["code", "development", "software", "system", "build", "ship", 
                "debug", "test", "documentation", "quality", "architecture"]
    Enum.any?(keywords, &String.contains?(String.downcase(truism), &1))
  end
  
  defp generate_title(truism) do
    case truism.category do
      :tank_building_methodology ->
        "Tank Building in Practice: #{extract_key_concept(truism.text)}"
      :ai_distributed_systems ->
        "ELIAS Architecture Insight: #{extract_key_concept(truism.text)}"
      :quality_learning ->
        "Quality Engineering Truth: #{extract_key_concept(truism.text)}"
      _ ->
        "Development Philosophy: #{extract_key_concept(truism.text)}"
    end
  end
  
  defp extract_key_concept(text) do
    # Extract the main concept from truism text
    text
    |> String.split([",", ":", "-"])
    |> List.first()
    |> String.trim()
  end
  
  defp generate_problem_hook(truism) do
    case truism.category do
      :tank_building_methodology ->
        "Every developer faces the perfectionism trap. We spend weeks polishing code that nobody will use, optimizing performance that doesn't matter, and building features that miss the mark entirely. There's a better way."
        
      :ai_distributed_systems ->
        "Building AI systems that actually work in production requires more than just throwing models at problems. It demands systematic architecture, distributed thinking, and proven methodologies."
        
      :quality_learning ->
        "The software industry is littered with projects that failed not because of technical complexity, but because teams couldn't maintain quality while moving fast. The key is systematic approaches to quality."
        
      _ ->
        "Software development is full of conventional wisdom that sounds good but breaks down under pressure. Let's examine what actually works."
    end
  end
  
  defp explain_principle(truism) do
    case truism.category do
      :tank_building_methodology ->
        "This truism captures the essence of Tank Building methodology - our systematic approach to software development that prioritizes functionality over elegance in early stages. Like building a tank, we focus on making it work first, then making it beautiful."
        
      :ai_distributed_systems ->
        "In the ELIAS distributed AI system, this principle guides how we architect solutions across six always-on managers. Each manager embodies this philosophy in its specialized domain."
        
      _ ->
        "This principle reflects years of engineering experience distilled into actionable wisdom. It's not just a nice saying - it's a methodology that produces measurable results."
    end
  end
  
  defp generate_elias_example(truism) do
    "When we implemented ULM (Universal Learning Manager) as the 6th manager in ELIAS, we applied this exact principle. Instead of designing a perfect learning system from the start, we focused on basic document ingestion and text conversion. The Jakob Uszkoreit interview conversion - 960 lines, 86,708 characters - proved the concept worked. Only then did we add pseudo-compilation, harmonization, and advanced learning features."
  end
  
  defp generate_code_example(truism) do
    case truism.category do
      :tank_building_methodology ->
        """
        # Stage 1: Make it work (Tank Building approach)
        def convert_document(input, output) do
          # Brute force: direct system call to pandoc
          case System.cmd("pandoc", [input, "-o", output]) do
            {_, 0} -> {:ok, "Converted successfully"}
            {error, _} -> {:error, error}
          end
        end
        
        # Stage 2: Make it better (after Stage 1 proves concept)
        def convert_document(input, output, opts \\\\ []) do
          with {:ok, format} <- detect_format(input, opts),
               {:ok, _} <- validate_input(input),
               {:ok, result} <- perform_conversion(input, output, format) do
            {:ok, result}
          else
            {:error, reason} -> {:error, reason}
          end
        end
        """
        
      _ ->
        """
        # ELIAS ULM implementation following the principle
        defmodule EliasServer.Manager.ULM do
          use GenServer
          
          def handle_call({:convert_text, input, output, format, opts}, _from, state) do
            # Apply the principle in real ELIAS code
            case EliasUtils.MultiFormatTextConverter.convert(input, output, opts) do
              {:ok, message} -> 
                # Stage 1: Basic conversion works
                {:reply, {:ok, message}, state}
              {:error, reason} -> 
                {:reply, {:error, reason}, state}
            end
          end
        end
        """
    end
  end
  
  defp generate_results_section(truism) do
    "In our ELIAS implementation, this approach delivered measurable results:\n\n" <>
    "- **Jakob Interview Conversion**: 960 lines processed successfully in Stage 1\n" <>
    "- **Time to Working System**: 2 days vs. estimated 2 weeks for 'perfect' solution\n" <>
    "- **Foundation Quality**: Stage 1 implementation supports all Stage 2+ features\n" <>
    "- **Team Confidence**: Working system early enabled fearless iteration\n\n" <>
    "The key insight: 'Working' doesn't mean 'sloppy' - it means 'focused on the essential problem.'"
  end
  
  defp generate_next_steps(truism) do
    case truism.tank_building_stage do
      1 -> 
        "1. **Identify your Stage 1 goal**: What's the minimum that proves your concept?\n" <>
        "2. **Resist feature creep**: Build only what's needed for Stage 1 success\n" <>
        "3. **Define success criteria**: How will you know Stage 1 is complete?\n" <>
        "4. **Plan Stage 2**: What would you add once Stage 1 works?"
        
      2 ->
        "1. **Preserve Stage 1**: Ensure new features don't break existing functionality\n" <>
        "2. **Add systematically**: One capability at a time, with full testing\n" <>
        "3. **Document evolution**: Track what changes and why\n" <>
        "4. **Measure impact**: Quantify improvements from Stage 1"
        
      _ ->
        "1. **Apply to your next feature**: Start with Tank Building Stage 1\n" <>
        "2. **Challenge perfectionism**: Ask 'Does this need to be perfect to work?'\n" <>
        "3. **Measure and iterate**: Use data to guide Stage 2+ improvements\n" <>
        "4. **Share your results**: Document what you learn"
    end
  end
  
  defp generate_takeaway(truism) do
    "#{truism.text} isn't just about accepting lower quality - it's about focusing quality efforts where they matter most. Build the foundation solid, then iterate with confidence."
  end
  
  defp generate_tags(truism) do
    base_tags = ["tank-building", "elias", "development-methodology"]
    
    category_tags = case truism.category do
      :tank_building_methodology -> ["methodology", "iterative-development"]
      :ai_distributed_systems -> ["ai-systems", "distributed-architecture"] 
      :quality_learning -> ["quality-engineering", "systematic-development"]
      _ -> ["software-development", "engineering-philosophy"]
    end
    
    (base_tags ++ category_tags) |> Enum.join(", ")
  end
  
  defp generate_metadata(truism, opts) do
    %{
      title: generate_title(truism),
      truism_source: truism.text,
      category: truism.category,
      tank_building_stage: truism.tank_building_stage,
      t_shirt_ready: truism.t_shirt_ready,
      channels: determine_channels(opts),
      creation_date: Date.utc_today(),
      status: "draft"
    }
  end
  
  defp determine_channels(opts) do
    channels = ["blog"]
    
    channels = if opts[:youtube], do: ["youtube" | channels], else: channels
    channels = if opts[:podcast], do: ["podcast" | channels], else: channels
    
    channels
  end
  
  defp generate_filename(truism) do
    truism.text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/, "")
    |> String.split()
    |> Enum.take(5)  # First 5 words
    |> Enum.join("_")
    |> Kernel.<>(".md")
  end
end