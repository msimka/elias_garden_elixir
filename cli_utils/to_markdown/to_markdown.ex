defmodule EliasUtils.MultiFormatTextConverter do
  @moduledoc """
  ELIAS Multi-Format Text Converter

  A Swiss Army Knife text converter for the ELIAS system that converts 
  multiple document formats to clean, standardized Markdown with metadata.
  
  This converter is designed to grow incrementally - each new format is added
  in a brute force way first, then optimized once multiple formats work.

  ## Supported Formats
  - RTF/RTFD (Rich Text Format)
  - PDF (Portable Document Format) 
  - DOCX (Microsoft Word)
  - HTML (Web pages)
  - TXT (Plain text)
  - DOC (Legacy Word)
  - ODT (OpenDocument)
  - EPUB (E-books)

  ## Usage
      iex> EliasUtils.MultiFormatTextConverter.convert("document.pdf", "document.md")
      {:ok, "Successfully converted document.pdf to document.md"}

      iex> EliasUtils.MultiFormatTextConverter.convert("paper.rtf", "paper.md", extract_meta: true)
      {:ok, "Successfully converted paper.rtf to paper.md with metadata"}
  """

  require Logger

  @supported_formats ~w(rtf rtfd pdf docx html htm txt doc odt epub)
  @pandoc_formats ~w(docx html htm txt doc odt epub)
  @pdf_formats ~w(pdf)
  @rtf_formats ~w(rtf rtfd)

  @doc """
  Convert a file to Markdown format.

  ## Options
  - `:format` - Force input format detection
  - `:extract_meta` - Extract metadata to frontmatter (default: false)
  - `:clean` - Clean and normalize output (default: true)
  - `:verbose` - Enable verbose logging (default: false)

  ## Examples
      convert("document.pdf", "document.md")
      convert("paper.rtf", "paper.md", extract_meta: true, clean: true)
  """
  def convert(input_path, output_path, opts \\ []) do
    with :ok <- validate_input(input_path),
         {:ok, format} <- detect_format(input_path, opts[:format]),
         :ok <- check_dependencies(format),
         {:ok, content} <- convert_to_markdown(input_path, format, opts),
         {:ok, final_content} <- post_process(content, input_path, opts),
         :ok <- File.write(output_path, final_content) do
      
      if opts[:verbose] do
        Logger.info("✅ Converted #{input_path} (#{format}) to #{output_path}")
      end
      
      {:ok, "Successfully converted #{input_path} to #{output_path}"}
    else
      {:error, reason} -> 
        Logger.error("❌ Conversion failed: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Batch convert multiple files using glob patterns.

  ## Examples
      batch_convert("papers/*.pdf", "./markdown/", extract_meta: true)
      batch_convert("docs/*.rtf", "./converted/", clean: true)
  """
  def batch_convert(input_pattern, output_dir, opts \\ []) do
    input_files = Path.wildcard(input_pattern)
    
    if Enum.empty?(input_files) do
      {:error, "No files found matching pattern: #{input_pattern}"}
    else
      File.mkdir_p!(output_dir)
      
      results = Enum.map(input_files, fn input_path ->
        filename = Path.basename(input_path, Path.extname(input_path))
        output_path = Path.join(output_dir, "#{filename}.md")
        
        case convert(input_path, output_path, opts) do
          {:ok, _msg} -> {:ok, input_path}
          {:error, reason} -> {:error, {input_path, reason}}
        end
      end)
      
      successes = Enum.count(results, fn {status, _} -> status == :ok end)
      failures = Enum.filter(results, fn {status, _} -> status == :error end)
      
      if opts[:verbose] do
        Logger.info("📊 Batch conversion: #{successes} succeeded, #{length(failures)} failed")
        Enum.each(failures, fn {:error, {file, reason}} ->
          Logger.error("Failed: #{file} - #{reason}")
        end)
      end
      
      {:ok, %{successes: successes, failures: failures, total: length(input_files)}}
    end
  end

  @doc """
  List supported formats and check system dependencies.
  """
  def system_info do
    deps = check_all_dependencies()
    
    %{
      supported_formats: @supported_formats,
      dependencies: deps,
      all_available: Enum.all?(Map.values(deps))
    }
  end

  # Private Functions

  defp validate_input(input_path) do
    cond do
      not File.exists?(input_path) ->
        {:error, "Input file not found: #{input_path}"}
      
      File.dir?(input_path) ->
        {:error, "Input path is a directory, not a file: #{input_path}"}
      
      true ->
        :ok
    end
  end

  defp detect_format(input_path, forced_format) do
    cond do
      forced_format && forced_format in @supported_formats ->
        {:ok, String.to_atom(forced_format)}
      
      forced_format ->
        {:error, "Unsupported format: #{forced_format}. Supported: #{Enum.join(@supported_formats, ", ")}"}
      
      true ->
        extension = Path.extname(input_path) |> String.trim_leading(".") |> String.downcase()
        
        if extension in @supported_formats do
          {:ok, String.to_atom(extension)}
        else
          # Try content detection
          detect_format_by_content(input_path)
        end
    end
  end

  defp detect_format_by_content(input_path) do
    # Read first 512 bytes for content detection
    case File.open(input_path, [:read], fn file -> IO.binread(file, 512) end) do
      {:ok, content} ->
        cond do
          String.starts_with?(content, "%PDF") -> {:ok, :pdf}
          String.contains?(content, "rtf1") -> {:ok, :rtf}
          String.contains?(content, "<html") or String.contains?(content, "<!DOCTYPE") -> {:ok, :html}
          true -> {:ok, :txt}  # Default to plain text
        end
      
      {:error, _} ->
        {:error, "Could not detect file format for: #{input_path}"}
    end
  end

  defp check_dependencies(format) do
    case format do
      format when format in [:pdf] ->
        if command_available?("pdftotext") do
          :ok
        else
          {:error, "pdftotext not found. Install poppler-utils: brew install poppler"}
        end
      
      format when format in [:rtf, :rtfd] ->
        cond do
          command_available?("textutil") -> :ok  # macOS
          command_available?("unrtf") -> :ok     # Linux/Windows
          command_available?("pandoc") -> :ok    # Fallback
          true -> {:error, "RTF converter not found. Install: textutil (macOS) or unrtf (Linux)"}
        end
      
      format when format in @pandoc_formats ->
        if command_available?("pandoc") do
          :ok
        else
          {:error, "pandoc not found. Install: brew install pandoc"}
        end
      
      _ ->
        :ok
    end
  end

  defp convert_to_markdown(input_path, format, opts) do
    case format do
      :pdf -> convert_pdf_to_markdown(input_path, opts)
      format when format in [:rtf, :rtfd] -> convert_rtf_to_markdown(input_path, opts)
      format when format in @pandoc_formats -> convert_with_pandoc(input_path, format, opts)
      :txt -> convert_txt_to_markdown(input_path, opts)
      _ -> {:error, "Unsupported format: #{format}"}
    end
  end

  defp convert_pdf_to_markdown(input_path, opts) do
    
    case System.cmd("pdftotext", ["-layout", input_path, "-"], stderr_to_stdout: true) do
      {output, 0} ->
        if opts[:verbose], do: Logger.info("📄 Extracted text from PDF: #{String.length(output)} characters")
        {:ok, output}
      
      {error, _} ->
        {:error, "pdftotext failed: #{error}"}
    end
  rescue
    e -> {:error, "PDF conversion error: #{Exception.message(e)}"}
  end

  defp convert_rtf_to_markdown(input_path, opts) do
    cond do
      command_available?("textutil") ->
        # macOS textutil - best for RTF/RTFD
        case System.cmd("textutil", ["-convert", "txt", "-stdout", input_path], stderr_to_stdout: true) do
          {output, 0} ->
            if opts[:verbose], do: Logger.info("📝 Converted RTF with textutil: #{String.length(output)} characters")
            {:ok, output}
          
          {error, _} ->
            {:error, "textutil failed: #{error}"}
        end
      
      command_available?("unrtf") ->
        # Linux/Windows unrtf
        case System.cmd("unrtf", ["--text", input_path], stderr_to_stdout: true) do
          {output, 0} ->
            if opts[:verbose], do: Logger.info("📝 Converted RTF with unrtf: #{String.length(output)} characters")
            {:ok, output}
          
          {error, _} ->
            {:error, "unrtf failed: #{error}"}
        end
      
      command_available?("pandoc") ->
        # Fallback to pandoc
        convert_with_pandoc(input_path, :rtf, opts)
      
      true ->
        {:error, "No RTF converter available"}
    end
  rescue
    e -> {:error, "RTF conversion error: #{Exception.message(e)}"}
  end

  defp convert_with_pandoc(input_path, format, opts) do
    # Use pandoc for most formats
    format_str = case format do
      :docx -> "docx"
      :html -> "html"
      :htm -> "html"
      :odt -> "odt"
      :epub -> "epub"
      :doc -> "doc"
      _ -> "auto"
    end
    
    args = [
      "--from", format_str,
      "--to", "markdown",
      "--wrap=none",
      input_path
    ]
    
    case System.cmd("pandoc", args, stderr_to_stdout: true) do
      {output, 0} ->
        if opts[:verbose] do
          Logger.info("🔄 Converted #{format} with pandoc: #{String.length(output)} characters")
        end
        {:ok, output}
      
      {error, _} ->
        {:error, "pandoc failed: #{error}"}
    end
  rescue
    e -> {:error, "Pandoc conversion error: #{Exception.message(e)}"}
  end

  defp convert_txt_to_markdown(input_path, _opts) do
    # Plain text - just read and potentially format
    case File.read(input_path) do
      {:ok, content} ->
        # Basic text-to-markdown formatting
        formatted = content
        |> String.replace(~r/\n\n+/, "\n\n")  # Normalize paragraph breaks
        |> String.replace(~r/^(.+):\s*$/m, "## \\1")  # Convert "Title:" to headers
        
        {:ok, formatted}
      
      {:error, reason} ->
        {:error, "Failed to read text file: #{reason}"}
    end
  end

  defp post_process(content, input_path, opts) do
    processed = content
    |> maybe_clean(opts[:clean])
    |> maybe_add_metadata(input_path, opts[:extract_meta])
    
    {:ok, processed}
  end

  defp maybe_clean(content, true) do
    content
    |> String.replace(~r/\n\s*\n\s*\n+/m, "\n\n")  # Remove excessive line breaks
    |> String.replace(~r/[ \t]+/m, " ")             # Normalize spaces
    |> String.replace(~r/\n +/m, "\n")              # Remove leading spaces on lines
    |> String.trim()                                 # Trim whitespace
  end
  
  defp maybe_clean(content, _), do: content

  defp maybe_add_metadata(content, input_path, true) do
    filename = Path.basename(input_path)
    extension = Path.extname(input_path) |> String.trim_leading(".")
    
    metadata = """
    ---
    title: "#{Path.basename(input_path, Path.extname(input_path))}"
    source_file: "#{filename}"
    converted_at: "#{DateTime.utc_now() |> DateTime.to_iso8601()}"
    format: "#{extension}"
    converter: "elias_multi_format_text_converter"
    ---

    """
    
    metadata <> content
  end
  
  defp maybe_add_metadata(content, _, _), do: content

  defp command_available?(command) do
    case System.cmd("which", [command], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  defp check_all_dependencies do
    %{
      pandoc: command_available?("pandoc"),
      pdftotext: command_available?("pdftotext"),
      textutil: command_available?("textutil"),
      unrtf: command_available?("unrtf")
    }
  end
end