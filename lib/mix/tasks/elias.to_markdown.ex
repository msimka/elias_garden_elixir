defmodule Mix.Tasks.Elias.ToMarkdown do
  @moduledoc """
  ELIAS Multi-Format Text Converter Mix Task (ULM Integration)

  Swiss Army Knife text converter managed by ULM (Universal Learning Manager)
  Supports RTF, RTFD, PDF, DOCX, HTML, TXT, DOC, ODT, EPUB → Markdown with learning sandbox integration

  ## Usage

      mix elias.to_markdown --input document.pdf --output document.md
      mix elias.to_markdown -i paper.rtf -o paper.md --extract-meta --sandbox
      mix elias.to_markdown -i "docs/*.pdf" -d "./markdown/" --clean --ingest

  ## Options

    * `-i, --input` - Input file path or glob pattern (required)
    * `-o, --output` - Output file path (defaults to input filename with .md extension)  
    * `-d, --output-dir` - Output directory for batch conversion
    * `-f, --format` - Force input format (rtf|pdf|docx|html|txt|doc|odt|epub)
    * `-m, --extract-meta` - Extract metadata to frontmatter
    * `-c, --clean` - Clean and normalize output (default: true)
    * `-v, --verbose` - Verbose output
    * `-s, --sandbox` - Copy to learning sandbox after conversion
    * `--ingest` - Full ULM ingestion with metadata and categorization
    * `-h, --help` - Show this help message
    * `--check-deps` - Check system dependencies

  ## Examples

      # Convert single file via ULM
      mix elias.to_markdown -i research_paper.pdf -o paper.md -m --ingest

      # Batch convert with learning sandbox integration  
      mix elias.to_markdown -i "papers/*.pdf" -d "./converted/" -c -v --sandbox

      # Convert RTF with full ULM ingestion
      mix elias.to_markdown -i document.rtf -m -v --ingest

      # Check system dependencies
      mix elias.to_markdown --check-deps
  """

  use Mix.Task

  @shortdoc "ELIAS Multi-Format Text Converter via ULM - Swiss Army Knife with learning integration"
  @requirements ["app.start"]

  def run(args) do
    {opts, args, _invalid} = OptionParser.parse(args,
      switches: [
        input: :string,
        output: :string,
        output_dir: :string,
        format: :string,
        extract_meta: :boolean,
        clean: :boolean,
        verbose: :boolean,
        sandbox: :boolean,
        ingest: :boolean,
        help: :boolean,
        check_deps: :boolean
      ],
      aliases: [
        i: :input,
        o: :output,
        d: :output_dir,
        f: :format,
        m: :extract_meta,
        c: :clean,
        v: :verbose,
        s: :sandbox,
        h: :help
      ]
    )

    cond do
      opts[:help] ->
        print_help()

      opts[:check_deps] ->
        check_dependencies()

      is_nil(opts[:input]) ->
        Mix.shell().error("Error: --input is required")
        print_help()

      opts[:output_dir] ->
        batch_convert(opts)

      true ->
        single_convert(opts)
    end
  end

  defp single_convert(opts) do
    input = opts[:input]
    output = opts[:output] || default_output_path(input)
    
    converter_opts = [
      format: opts[:format],
      extract_meta: opts[:extract_meta] || false,
      clean: opts[:clean] != false,  # Default to true
      verbose: opts[:verbose] || false
    ]

    if opts[:ingest] do
      # Use ULM for full ingestion with learning sandbox integration
      case convert_via_ulm(input, output, converter_opts) do
        {:ok, message} ->
          Mix.shell().info("🧠 ULM: #{message}")
          
        {:error, reason} ->
          Mix.shell().error("❌ ULM conversion failed: #{reason}")
          System.halt(1)
      end
    else
      # Direct conversion (legacy mode)
      case EliasUtils.MultiFormatTextConverter.convert(input, output, converter_opts) do
        {:ok, message} ->
          Mix.shell().info("✅ #{message}")
          
          # Optional sandbox copy
          if opts[:sandbox] do
            copy_to_learning_sandbox(output, opts)
          end

        {:error, reason} ->
          Mix.shell().error("❌ Conversion failed: #{reason}")
          System.halt(1)
      end
    end
  end

  defp batch_convert(opts) do
    input_pattern = opts[:input]
    output_dir = opts[:output_dir]
    
    converter_opts = [
      format: opts[:format],
      extract_meta: opts[:extract_meta] || false,
      clean: opts[:clean] != false,
      verbose: opts[:verbose] || false
    ]

    case EliasUtils.MultiFormatTextConverter.batch_convert(input_pattern, output_dir, converter_opts) do
      {:ok, %{successes: successes, failures: failures, total: total}} ->
        Mix.shell().info("📊 Batch conversion complete:")
        Mix.shell().info("   ✅ #{successes} files converted successfully")
        
        if length(failures) > 0 do
          Mix.shell().error("   ❌ #{length(failures)} files failed:")
          Enum.each(failures, fn {:error, {file, reason}} ->
            Mix.shell().error("      #{Path.basename(file)}: #{reason}")
          end)
        end
        
        Mix.shell().info("   📁 Output directory: #{output_dir}")

      {:error, reason} ->
        Mix.shell().error("❌ Batch conversion failed: #{reason}")
        System.halt(1)
    end
  end

  defp check_dependencies do
    info = EliasUtils.MultiFormatTextConverter.system_info()
    
    Mix.shell().info("🔧 ELIAS Multi-Format Text Converter - System Dependencies")
    Mix.shell().info("")
    Mix.shell().info("Supported formats: #{Enum.join(info.supported_formats, ", ")}")
    Mix.shell().info("")
    Mix.shell().info("Dependencies:")
    
    Enum.each(info.dependencies, fn {tool, available} ->
      status = if available, do: "✅", else: "❌"
      Mix.shell().info("  #{status} #{tool}")
    end)
    
    Mix.shell().info("")
    
    if info.all_available do
      Mix.shell().info("🎉 All dependencies are available!")
    else
      Mix.shell().error("⚠️  Some dependencies are missing. Install instructions:")
      Mix.shell().info("")
      Mix.shell().info("macOS (Homebrew):")
      Mix.shell().info("  brew install pandoc poppler")
      Mix.shell().info("")
      Mix.shell().info("Ubuntu/Debian:")
      Mix.shell().info("  sudo apt install pandoc poppler-utils unrtf")
      Mix.shell().info("")
      Mix.shell().info("Windows (Chocolatey):")
      Mix.shell().info("  choco install pandoc poppler unrtf")
    end
  end

  defp default_output_path(input_path) do
    base_name = Path.basename(input_path, Path.extname(input_path))
    Path.join(Path.dirname(input_path), "#{base_name}.md")
  end

  defp convert_via_ulm(input, output, converter_opts) do
    # Simulate ULM integration (would use GenServer.call in production)
    case EliasUtils.MultiFormatTextConverter.convert(input, output, converter_opts) do
      {:ok, message} ->
        # Simulate ULM document ingestion
        ingest_result = simulate_ulm_ingestion(input, output)
        {:ok, "#{message} + ULM ingestion: #{ingest_result}"}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp simulate_ulm_ingestion(input, output) do
    # In production, this would be: GenServer.call(EliasServer.Manager.ULM, {:ingest_document, input, output, %{}})
    sandbox_path = "/Users/mikesimka/elias_garden_elixir/learning_sandbox"
    
    cond do
      String.contains?(input, "paper") or String.contains?(input, "research") ->
        copy_to_sandbox_category(output, Path.join([sandbox_path, "papers", "by_date"]))
        "Academic paper categorized and indexed"
        
      String.contains?(input, "interview") or String.contains?(input, "transcript") ->
        copy_to_sandbox_category(output, Path.join([sandbox_path, "transcripts", "by_source"]))
        "Interview transcript processed and archived"
        
      true ->
        copy_to_sandbox_category(output, Path.join([sandbox_path, "notes", "raw_ideas"]))
        "Document ingested into learning sandbox"
    end
  end
  
  defp copy_to_learning_sandbox(output, opts) do
    sandbox_path = "/Users/mikesimka/elias_garden_elixir/learning_sandbox/notes/raw_ideas"
    
    if File.exists?(sandbox_path) do
      filename = Path.basename(output)
      destination = Path.join(sandbox_path, filename)
      
      case File.cp(output, destination) do
        :ok ->
          if opts[:verbose] do
            Mix.shell().info("📚 Copied to learning sandbox: #{filename}")
          end
          
        {:error, reason} ->
          Mix.shell().error("⚠️  Failed to copy to sandbox: #{reason}")
      end
    end
  end
  
  defp copy_to_sandbox_category(output, category_path) do
    File.mkdir_p(category_path)
    filename = Path.basename(output)
    destination = Path.join(category_path, filename)
    
    case File.cp(output, destination) do
      :ok -> :ok
      {:error, _reason} -> :error
    end
  end

  defp print_help do
    Mix.shell().info(@moduledoc)
  end
end