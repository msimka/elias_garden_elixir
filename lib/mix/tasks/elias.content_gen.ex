defmodule Mix.Tasks.Elias.ContentGen do
  @moduledoc """
  ELIAS Content Generation Mix Task (ULM Integration)
  
  Generate content from truisms following Tank Building methodology and architect guidance
  
  ## Usage
  
      mix elias.content_gen --truism "Tank Building: Brute force first, elegant second" --channel blog
      mix elias.content_gen --truism "Six managers, infinite possibilities" --channel blog --youtube --podcast
      mix elias.content_gen --list-truisms
      mix elias.content_gen --validate-truism "Perfect is the enemy of shipped"
  
  ## Options
  
    * `--truism` - The truism text to generate content from (required unless --list-truisms)
    * `--channel` - Target channel: blog, youtube, podcast, merchandise (default: blog) 
    * `--youtube` - Also generate YouTube follow-up content
    * `--podcast` - Also generate podcast discussion points
    * `--output-dir` - Output directory (default: content_branding/blog/)
    * `--validate-truism` - Validate a truism against ELIAS standards
    * `--list-truisms` - List all available truisms from the system
    * `--tank-building-stage` - Force specific Tank Building stage (1-4)
    * `--verbose` - Verbose output with ULM integration details
    * `--help` - Show this help message
  
  ## Examples
  
      # Generate blog post from truism
      mix elias.content_gen --truism "Build it to work, then make it beautiful" --channel blog
      
      # Multi-channel content generation
      mix elias.content_gen --truism "Systematic beats sporadic every single time" --youtube --podcast
      
      # Validate truism for brand compliance
      mix elias.content_gen --validate-truism "Innovation isn't inspiration - it's iteration"
      
      # List all available truisms
      mix elias.content_gen --list-truisms
  """
  
  use Mix.Task
  
  @shortdoc "ELIAS Content Generation via ULM - Create content from truisms following Tank Building methodology"
  @requirements ["app.start"]
  
  def run(args) do
    {opts, args, _invalid} = OptionParser.parse(args,
      switches: [
        truism: :string,
        channel: :string,
        output_dir: :string,
        validate_truism: :string,
        list_truisms: :boolean,
        tank_building_stage: :integer,
        youtube: :boolean,
        podcast: :boolean,
        verbose: :boolean,
        help: :boolean
      ],
      aliases: [
        t: :truism,
        c: :channel,
        o: :output_dir,
        v: :verbose,
        h: :help
      ]
    )
    
    cond do
      opts[:help] ->
        print_help()
        
      opts[:list_truisms] ->
        list_available_truisms()
        
      opts[:validate_truism] ->
        validate_truism_command(opts[:validate_truism])
        
      is_nil(opts[:truism]) ->
        Mix.shell().error("Error: --truism is required")
        print_help()
        
      true ->
        generate_content(opts)
    end
  end
  
  defp generate_content(opts) do
    truism = opts[:truism]
    channel = String.to_atom(opts[:channel] || "blog")
    output_dir = opts[:output_dir] || default_output_dir(channel)
    
    generation_opts = [
      youtube: opts[:youtube] || false,
      podcast: opts[:podcast] || false,
      tank_building_stage: opts[:tank_building_stage],
      verbose: opts[:verbose] || false
    ]
    
    Mix.shell().info("🧠 ULM Content Generation: Processing truism...")
    if opts[:verbose] do
      Mix.shell().info("   Truism: \"#{truism}\"")
      Mix.shell().info("   Channel: #{channel}")
      Mix.shell().info("   Output: #{output_dir}")
    end
    
    # Load content generator (would use ULM GenServer in production)
    Code.require_file("content_branding/automation/generate_blog_from_truism.ex")
    
    case EliasContent.BlogGenerator.generate_from_truism(truism, channel, generation_opts) do
      {:ok, content} ->
        write_generated_content(content, output_dir, opts)
        
      {:error, reason} ->
        Mix.shell().error("❌ Content generation failed: #{reason}")
        System.halt(1)
    end
  end
  
  defp write_generated_content(content, output_dir, opts) do
    File.mkdir_p!(output_dir)
    
    output_path = Path.join(output_dir, content.filename)
    
    case File.write(output_path, content.content) do
      :ok ->
        Mix.shell().info("✅ Content generated successfully!")
        Mix.shell().info("   📄 File: #{output_path}")
        Mix.shell().info("   📰 Title: #{content.metadata.title}")
        Mix.shell().info("   🏷️ Category: #{content.metadata.category}")
        Mix.shell().info("   🏗️ Tank Building Stage: #{content.metadata.tank_building_stage}")
        
        if content.metadata.t_shirt_ready do
          Mix.shell().info("   👕 T-shirt ready: Yes")
        end
        
        Mix.shell().info("   📺 Channels: #{Enum.join(content.metadata.channels, ", ")}")
        
        # Generate metadata file
        metadata_path = Path.join(output_dir, Path.basename(content.filename, ".md") <> ".metadata.yaml")
        metadata_yaml = generate_metadata_yaml(content.metadata)
        
        case File.write(metadata_path, metadata_yaml) do
          :ok ->
            if opts[:verbose] do
              Mix.shell().info("   📋 Metadata: #{metadata_path}")
            end
          {:error, reason} ->
            Mix.shell().error("⚠️  Failed to write metadata: #{reason}")
        end
        
      {:error, reason} ->
        Mix.shell().error("❌ Failed to write content file: #{reason}")
        System.halt(1)
    end
  end
  
  defp validate_truism_command(truism) do
    Mix.shell().info("🔍 Validating truism against ELIAS brand standards...")
    Mix.shell().info("   \"#{truism}\"")
    
    # Load content generator
    Code.require_file("content_branding/automation/generate_blog_from_truism.ex")
    
    case EliasContent.BlogGenerator.validate_truism(truism) do
      {:ok, validated} ->
        Mix.shell().info("✅ Truism validation passed!")
        Mix.shell().info("   📂 Category: #{validated.category}")
        Mix.shell().info("   👕 T-shirt ready: #{if validated.t_shirt_ready, do: "Yes", else: "No"}")
        Mix.shell().info("   🏗️ Tank Building stage: #{validated.tank_building_stage}")
        Mix.shell().info("   📏 Length: #{String.length(truism)} characters")
        
        if validated.t_shirt_ready do
          Mix.shell().info("   🎯 Perfect for merchandise and social media")
        end
        
      {:error, reason} ->
        Mix.shell().error("❌ Truism validation failed: #{reason}")
        Mix.shell().info("")
        Mix.shell().info("💡 Tips for ELIAS-compliant truisms:")
        Mix.shell().info("   • Keep under 200 characters for blog generation")
        Mix.shell().info("   • Include Tank Building, ELIAS, or development keywords")
        Mix.shell().info("   • Make it conversation-starter worthy")
        Mix.shell().info("   • Align with systematic development philosophy")
    end
  end
  
  defp list_available_truisms do
    Mix.shell().info("🎯 Available ELIAS Truisms (from truisms_and_taglines.md)")
    Mix.shell().info("=" |> String.duplicate(60))
    
    truisms_file = "content_branding/truisms_and_taglines.md"
    
    if File.exists?(truisms_file) do
      {:ok, content} = File.read(truisms_file)
      
      # Extract truisms (lines starting with - **)
      truisms = content
                |> String.split("\n")
                |> Enum.filter(&String.match?(&1, ~r/^- \*\*.*\*\*/))
                |> Enum.map(&extract_truism_text/1)
                |> Enum.with_index(1)
      
      Enum.each(truisms, fn {truism, index} ->
        Mix.shell().info("#{index |> to_string() |> String.pad_leading(2)}. #{truism}")
      end)
      
      Mix.shell().info("")
      Mix.shell().info("📊 Total: #{length(truisms)} truisms available")
      Mix.shell().info("💡 Use any of these with --truism flag for content generation")
      
    else
      Mix.shell().error("❌ Truisms file not found: #{truisms_file}")
      Mix.shell().info("Run this from the ELIAS root directory")
    end
  end
  
  defp extract_truism_text(line) do
    # Extract text between ** markers
    case Regex.run(~r/\*\*(.*?)\*\*/, line) do
      [_, truism] -> truism
      _ -> String.trim(line)
    end
  end
  
  defp default_output_dir(channel) do
    case channel do
      :blog -> "content_branding/blog/"
      :youtube -> "content_branding/video_content/"
      :podcast -> "content_branding/podcast/"
      :merchandise -> "content_branding/merchandise/"
      _ -> "content_branding/blog/"
    end
  end
  
  defp generate_metadata_yaml(metadata) do
    """
    # Generated by ELIAS Content Generation (ULM Integration)
    title: "#{metadata.title}"
    truism_source: "#{metadata.truism_source}"
    category: #{metadata.category}
    tank_building_stage: #{metadata.tank_building_stage}
    t_shirt_ready: #{metadata.t_shirt_ready}
    channels: #{inspect(metadata.channels)}
    creation_date: "#{metadata.creation_date}"
    status: "#{metadata.status}"
    
    # ELIAS Integration
    ulm_generated: true
    tiki_compliant: true
    brand_voice_validated: true
    
    # Quality Gates  
    pseudo_compilation_status: "pending"
    harmonization_review: "pending"
    tank_building_stage_verified: true
    """
  end
  
  defp print_help do
    Mix.shell().info(@moduledoc)
  end
end