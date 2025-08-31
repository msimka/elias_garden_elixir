defmodule MFC.CLI do
  @moduledoc """
  Multi-Format Converter - Global CLI Application
  
  ELIAS Learning Pipeline Integration
  Converts RTF/PDF/DOCX/TXT → Markdown → ULM Learning System
  
  Usage:
    mfc document.rtf
    mfc paper.pdf --type=paper
    mfc japanese_doc.txt --lang=ja
  """

  require Logger
  
  alias MultiFormatConverter.Pipeline.ConverterOrchestrator
  alias MultiFormatConverter.FormatDetection.FormatDetector

  @learning_inbox "learning_sandbox/ulm_inbox"
  @learning_processed "learning_sandbox/ulm_processed"

  def main(args) do
    case parse_args(args) do
      {:ok, options} ->
        execute_command(options)
      {:error, message} ->
        IO.puts(:stderr, "Error: #{message}")
        show_help()
        System.halt(1)
    end
  end

  defp parse_args([]), do: {:ok, %{command: :help}}
  defp parse_args(["--help"]), do: {:ok, %{command: :help}}
  defp parse_args(["-h"]), do: {:ok, %{command: :help}}
  defp parse_args(["--status"]), do: {:ok, %{command: :status}}

  defp parse_args(args) do
    {options, files, _} = OptionParser.parse(args,
      strict: [
        type: :string,
        lang: :string,
        output: :string,
        help: :boolean,
        status: :boolean
      ],
      aliases: [
        t: :type,
        l: :lang,
        o: :output,
        h: :help
      ]
    )

    case files do
      [file] ->
        {:ok, Map.merge(%{
          command: :convert,
          file: file,
          type: options[:type] || auto_detect_type(file),
          language: options[:lang] || "en",
          output: options[:output]
        }, Map.new(options))}
      [] ->
        {:ok, %{command: :help}}
      _ ->
        {:error, "Multiple files not supported yet"}
    end
  end

  defp execute_command(%{command: :help}), do: show_help()
  defp execute_command(%{command: :status}), do: show_status()
  defp execute_command(%{command: :convert} = options), do: convert_file(options)

  defp show_help do
    IO.puts """
    🔧 MFC - Multi-Format Converter (ELIAS Learning Pipeline)

    USAGE:
        mfc <file>                    Convert file for AI learning
        mfc <file> --lang=ja         Convert Japanese content  
        mfc <file> --type=paper      Convert academic paper
        mfc <file> --type=transcript Convert video transcript
        mfc --status                 Show system status
        mfc --help                   Show this help

    EXAMPLES:
        mfc ~/Downloads/paper.pdf              # Convert PDF to learning pipeline
        mfc transcript.rtf --type=transcript   # Convert RL video transcript
        mfc japanese_doc.txt --lang=ja         # Convert Japanese content
        
    INTEGRATION:
        • Converts RTF/PDF/DOCX/TXT → Markdown
        • Delivers to ULM learning pipeline  
        • Ready for AI-assisted learning with Claude
        • Supports Japanese language content

    FILES PROCESSED TO:
        📥 ULM Inbox: #{@learning_inbox}/
        ✅ Processed: #{@learning_processed}/
    """
  end

  defp show_status do
    IO.puts "🔧 ELIAS Multi-Format Converter Status\n"
    
    elias_root = System.get_env("PWD") || File.cwd!()
    inbox_path = Path.join(elias_root, @learning_inbox)
    processed_path = Path.join(elias_root, @learning_processed)
    
    # Ensure directories exist
    File.mkdir_p!(inbox_path)
    File.mkdir_p!(processed_path)
    
    inbox_count = count_files(inbox_path)
    processed_count = count_files(processed_path)
    
    IO.puts "📂 Learning Pipeline:"
    IO.puts "   Inbox: #{inbox_path} (#{inbox_count} files)"
    IO.puts "   Processed: #{processed_path} (#{processed_count} files)"
    IO.puts ""
    IO.puts "🎯 ELIAS System:"
    
    # Check if ELIAS is running
    case System.cmd("pgrep", ["-f", "beam.smp.*elias"], stderr_to_stdout: true) do
      {_, 0} -> IO.puts "   ELIAS Server: ✅ Running"
      {_, _} -> IO.puts "   ELIAS Server: ❌ Not running"
    end
    
    IO.puts "   Multi-Format Converter: ✅ Available"
    IO.puts "   ULM Learning Pipeline: 🔄 Ready for integration"
  end

  defp convert_file(%{file: file} = options) do
    case File.exists?(file) do
      false ->
        IO.puts(:stderr, "Error: File not found: #{file}")
        System.halt(1)
      
      true ->
        IO.puts "🔄 Converting: #{file}"
        IO.puts "📋 Type: #{options.type} | Language: #{options.language}"
        
        case do_conversion(file, options) do
          {:ok, output_path} ->
            IO.puts "✅ Conversion successful!"
            IO.puts "📁 Output: #{output_path}"
            IO.puts "🎓 Ready for AI learning with ULM!"
            
          {:error, reason} ->
            IO.puts(:stderr, "❌ Conversion failed: #{inspect(reason)}")
            System.halt(1)
        end
    end
  end

  defp do_conversion(input_file, options) do
    # Get absolute path
    input_path = Path.expand(input_file)
    
    # Generate output path
    output_path = generate_output_path(input_path, options)
    
    # Ensure output directory exists
    File.mkdir_p!(Path.dirname(output_path))
    
    # Read file content for format detection
    case File.read(input_path) do
      {:ok, file_content} ->
        # Detect format
        case FormatDetector.detect_format(file_content) do
          {:ok, format} ->
            # Convert using ConverterOrchestrator
            case ConverterOrchestrator.convert_file_with_options(input_path, output_path, [
              format_hint: format,
              extraction_options: [content_type: options.type, language: options.language]
            ]) do
              {:ok, result} ->
                # Add ULM metadata
                add_ulm_metadata(output_path, input_path, options)
                
                # Clean up content
                cleaned_path = clean_and_process_content(output_path, input_path, options)
                
                # Create ULM notification
                create_ulm_notification(cleaned_path, options)
                
                {:ok, cleaned_path}
                
              {:error, reason} ->
                {:error, reason}
            end
            
          {:error, reason} ->
            {:error, "Format detection failed: #{reason}"}
        end
        
      {:error, reason} ->
        {:error, "File read failed: #{reason}"}
    end
  end

  defp generate_output_path(input_path, options) do
    # Get base filename without extension
    base_name = input_path |> Path.basename() |> Path.rootname()
    
    # Generate timestamp
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic) |> String.replace(":", "")
    
    # Generate filename with metadata
    filename = "#{timestamp}_#{options.type}_#{base_name}.md"
    
    # Get ELIAS root (assuming we're running from within project)
    elias_root = find_elias_root() || File.cwd!()
    
    Path.join([elias_root, @learning_inbox, filename])
  end

  defp add_ulm_metadata(output_path, source_path, options) do
    # Read existing content
    {:ok, content} = File.read(output_path)
    
    # Create metadata header
    metadata = """
    ---
    # ELIAS ULM Learning Content
    ulm_metadata:
      source_file: "#{source_path}"
      content_type: "#{options.type}"
      language: "#{options.language}"
      converted_date: "#{DateTime.utc_now() |> DateTime.to_iso8601()}"
      converter_version: "mfc-1.0"
      ready_for_learning: true
    ---

    """
    
    # Write metadata + content
    File.write!(output_path, metadata <> content)
  end

  defp create_ulm_notification(output_path, options) do
    elias_root = find_elias_root() || File.cwd!()
    notification_file = Path.join([elias_root, @learning_inbox, ".ulm_notify"])
    
    notification_entry = "#{DateTime.utc_now() |> DateTime.to_iso8601()}|#{output_path}|#{options.type}|#{options.language}\n"
    
    File.write!(notification_file, notification_entry, [:append])
  end

  defp auto_detect_type(filename) do
    basename = String.downcase(Path.basename(filename))
    
    cond do
      String.contains?(basename, ["paper", "research", "arxiv", "journal", "academic"]) ->
        "paper"
      String.contains?(basename, ["transcript", "video", "youtube", "lecture", "talk"]) ->
        "transcript"
      String.contains?(basename, ["notes", "meeting", "summary"]) ->
        "notes"
      true ->
        "general"
    end
  end

  defp count_files(path) do
    case File.ls(path) do
      {:ok, files} -> 
        files 
        |> Enum.reject(&String.starts_with?(&1, "."))
        |> length()
      {:error, _} -> 0
    end
  end

  defp find_elias_root do
    # Try to find elias_garden_elixir directory by walking up
    current_dir = File.cwd!()
    find_elias_root_recursive(current_dir)
  end

  defp find_elias_root_recursive("/"), do: nil
  defp find_elias_root_recursive(path) do
    if String.ends_with?(path, "elias_garden_elixir") or 
       File.exists?(Path.join(path, "mix.exs")) do
      path
    else
      path |> Path.dirname() |> find_elias_root_recursive()
    end
  end

  defp clean_and_process_content(input_path, source_path, options) do
    {:ok, content} = File.read(input_path)
    
    # Extract the main content (skip metadata header)
    content_parts = String.split(content, "---", parts: 3)
    if length(content_parts) >= 3 do
      [_, metadata, main_content] = content_parts
      
      # Clean up the main content 
      cleaned_content = main_content
      |> clean_transcript_content(options.type)
      |> fix_grammar_and_formatting()
      |> normalize_whitespace()
      
      # Reconstruct with metadata
      final_content = "---\n#{metadata}---\n#{cleaned_content}"
      
      # Generate processed file path
      elias_root = find_elias_root() || File.cwd!()
      processed_path = generate_processed_path(input_path, elias_root)
      
      # Ensure processed directory exists
      File.mkdir_p!(Path.dirname(processed_path))
      
      # Write cleaned content to processed folder
      File.write!(processed_path, final_content)
      
      # Remove from inbox
      File.rm!(input_path)
      
      processed_path
    else
      # If no metadata header, just return original path
      input_path
    end
  end

  defp clean_transcript_content(content, "transcript") do
    content
    # Remove YouTube/transcript artifacts
    |> String.replace(~r/\[Music\]/i, "")
    |> String.replace(~r/\[Applause\]/i, "")
    |> String.replace(~r/\[Laughter\]/i, "")
    |> String.replace(~r/\[Inaudible\]/i, "")
    |> String.replace(~r/\[.*?\]/i, "")  # Remove other bracketed content
    
    # Fix repeated words and phrases
    |> remove_repeated_phrases()
    |> fix_run_on_sentences()
    |> add_paragraph_breaks()
  end

  defp clean_transcript_content(content, _type) do
    content
    |> fix_run_on_sentences()  
    |> add_paragraph_breaks()
  end

  defp remove_repeated_phrases(text) do
    # Remove repeated words like "the the the" 
    text
    |> String.replace(~r/\b(\w+)\s+\1\s+\1\b/i, "\\1")  # 3+ repeats -> 1
    |> String.replace(~r/\b(\w+)\s+\1\b/i, "\\1")       # 2 repeats -> 1
    
    # Remove repeated phrases like "you know you know"
    |> String.replace(~r/\b(you know)\s+\1\b/i, "\\1")
    |> String.replace(~r/\b(um|uh|er)\s+/i, " ")
    |> String.replace(~r/\b(so so|and and|but but)\b/i, fn match ->
      String.split(match, " ") |> List.first()
    end)
  end

  defp fix_run_on_sentences(text) do
    text
    # Add periods before common sentence starters
    |> String.replace(~r/\s+(so|and|but|now|then|well)\s+/i, ". \\1 ")
    |> String.replace(~r/\s+(however|therefore|meanwhile|furthermore)\s+/i, ". \\1 ")
    
    # Fix missing capitalization after periods
    |> String.replace(~r/\.\s+([a-z])/, fn match ->
      # Extract the letter that needs to be capitalized
      case Regex.run(~r/\.\s+([a-z])/, match, capture: :all_but_first) do
        [letter] -> String.replace(match, letter, String.upcase(letter))
        _ -> match
      end
    end)
  end

  defp add_paragraph_breaks(text) do
    text
    # Add paragraph breaks before major topic shifts
    |> String.replace(~r/\.\s+(now|so|okay|alright|next|moving on)/i, ".\\n\\n\\1")
    |> String.replace(~r/\.\s+(let me|I want to|we're going to)/i, ".\\n\\n\\1")
    
    # Break up very long paragraphs (more than 500 chars without line break)
    |> break_long_paragraphs()
  end

  defp break_long_paragraphs(text) do
    text
    |> String.split("\n")
    |> Enum.map(fn paragraph ->
      if String.length(paragraph) > 500 do
        # Find sentence boundaries and break into smaller chunks
        sentences = String.split(paragraph, ~r/\.\s+/, include_captures: true)
        chunk_sentences(sentences, 300)
      else
        paragraph
      end
    end)
    |> Enum.join("\n")
  end

  defp chunk_sentences(sentences, max_length) do
    sentences
    |> Enum.chunk_while("", fn sentence, acc ->
      new_acc = acc <> sentence
      if String.length(new_acc) > max_length and String.length(acc) > 0 do
        {:cont, acc, sentence}
      else
        {:cont, new_acc}
      end
    end, fn acc -> {:cont, acc, []} end)
    |> Enum.join("\n\n")
  end

  defp fix_grammar_and_formatting(text) do
    text
    # Fix common grammar issues
    |> String.replace(~r/\s+/, " ")  # Multiple spaces -> single space
    |> String.replace(~r/\s+\./, ".")  # Space before period
    |> String.replace(~r/\s+,/, ",")   # Space before comma
    |> String.replace(~r/\.{2,}/, ".")  # Multiple periods
    
    # Capitalize first letter of each sentence
    |> String.replace(~r/(^|\.\s+)([a-z])/, fn match ->
      String.replace(match, ~r/[a-z]$/, &String.upcase/1)
    end)
  end

  defp normalize_whitespace(text) do
    text
    |> String.replace(~r/\n\s*\n\s*\n+/, "\n\n")  # Max 2 line breaks
    |> String.replace(~r/[ \t]+/, " ")  # Multiple spaces/tabs -> single space
    |> String.trim()
  end

  defp generate_processed_path(input_path, elias_root) do
    filename = Path.basename(input_path)
    Path.join([elias_root, @learning_processed, filename])
  end
end