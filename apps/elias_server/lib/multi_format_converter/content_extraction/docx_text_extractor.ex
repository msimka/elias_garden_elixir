defmodule MultiFormatConverter.ContentExtraction.DocxTextExtractor do
  @moduledoc """
  Atomic Component 3.3: DocxTextExtractor
  
  RESPONSIBILITY: Extract text content from DOCX files - ONLY DOCX text extraction
  
  Based on Architect guidance:
  - Atomic granularity: One responsibility per component
  - Real testing: Extract from known DOCX files, verify text matches expected content
  - ZIP-based parsing: Uses Elixir's :zip module to handle DOCX structure
  - Blockchain verification: All tests signed and submitted to Level 2 rollup
  
  Tank Building Stage 2: Extend with DOCX extraction without breaking Stage 1
  """
  
  require Logger

  use MultiFormatConverter.AtomicComponent

  # DOCX parsing configuration
  @docx_xml_files ["word/document.xml", "word/header.xml", "word/footer.xml"]
  @max_docx_size_bytes 100 * 1024 * 1024  # 100MB limit for DOCX processing

  # Public API - Atomic Component Interface

  @doc """
  Extract text content from DOCX binary data
  
  Input: docx_content (binary) - DOCX file content to process
  Output: {:ok, text (string), metadata (map)} | {:error, reason}
  
  ATOMIC RESPONSIBILITY: ONLY DOCX text extraction, no format detection or processing
  """
  def extract_text(docx_content) when is_binary(docx_content) do
    Logger.debug("DocxTextExtractor: Processing #{byte_size(docx_content)} bytes of DOCX content")
    
    # Validate DOCX ZIP structure first
    case validate_docx_content(docx_content) do
      :ok ->
        extract_text_from_docx(docx_content)
        
      {:error, reason} ->
        Logger.error("DocxTextExtractor: Invalid DOCX content: #{reason}")
        {:error, {:invalid_docx, reason}}
    end
  end

  def extract_text(invalid_content) do
    Logger.error("DocxTextExtractor: Invalid content type: #{inspect(invalid_content)}")
    {:error, :invalid_content_type}
  end

  @doc """
  Extract text with additional options for DOCX processing
  
  Options:
  - include_headers_footers: boolean (default true)
  - include_comments: boolean (default false)
  - preserve_structure: boolean (default false) - preserve paragraphs/sections
  - extract_tables: boolean (default true)
  """
  def extract_text_with_options(docx_content, opts \\ []) when is_binary(docx_content) do
    Logger.debug("DocxTextExtractor: Processing with options: #{inspect(opts)}")
    
    case validate_docx_content(docx_content) do
      :ok ->
        extract_text_from_docx_with_options(docx_content, opts)
        
      {:error, reason} ->
        {:error, {:invalid_docx, reason}}
    end
  end

  @doc """
  Extract metadata from DOCX without full text extraction
  
  Useful for validation and information gathering
  """
  def extract_metadata_only(docx_content) when is_binary(docx_content) do
    Logger.debug("DocxTextExtractor: Extracting metadata only")
    
    case validate_docx_content(docx_content) do
      :ok ->
        extract_docx_metadata(docx_content)
        
      {:error, reason} ->
        {:error, {:invalid_docx, reason}}
    end
  end

  @doc """
  List all files in DOCX ZIP archive
  
  Returns list of files for debugging and analysis
  """
  def list_docx_files(docx_content) when is_binary(docx_content) do
    case :zip.unzip(docx_content, [:memory]) do
      {:ok, files} ->
        file_list = Enum.map(files, fn {filename, _content} -> 
          List.to_string(filename) 
        end)
        {:ok, file_list}
        
      {:error, reason} ->
        {:error, {:zip_error, reason}}
    end
  end

  # Private Implementation Functions

  defp validate_docx_content(content) do
    cond do
      byte_size(content) > @max_docx_size_bytes ->
        {:error, "docx_file_too_large"}
        
      not String.starts_with?(content, "PK") ->
        {:error, "invalid_zip_signature"}
        
      true ->
        # Try to open as ZIP and check for required DOCX files
        case :zip.unzip(content, [:memory]) do
          {:ok, files} ->
            file_names = Enum.map(files, fn {filename, _content} -> 
              List.to_string(filename) 
            end)
            
            # Check for required DOCX structure
            if Enum.any?(file_names, &String.contains?(&1, "word/document.xml")) and
               Enum.any?(file_names, &String.contains?(&1, "[Content_Types].xml")) do
              :ok
            else
              {:error, "missing_docx_structure"}
            end
            
          {:error, _reason} ->
            {:error, "invalid_zip_format"}
        end
    end
  end

  defp extract_text_from_docx(docx_content) do
    try do
      # Stage 2: Tank Building - extract from ZIP and parse XML
      case :zip.unzip(docx_content, [:memory]) do
        {:ok, files} ->
          # Find and extract text from main document
          document_text = extract_text_from_document_xml(files)
          headers_footers_text = extract_text_from_headers_footers(files)
          
          combined_text = combine_extracted_text([document_text, headers_footers_text])
          metadata = extract_metadata_from_zip_files(files)
          
          Logger.debug("DocxTextExtractor: Successfully extracted #{String.length(combined_text)} characters")
          {:ok, combined_text, metadata}
          
        {:error, reason} ->
          Logger.error("DocxTextExtractor: ZIP extraction failed: #{reason}")
          {:error, {:zip_extraction_failed, reason}}
      end
      
    rescue
      error ->
        Logger.error("DocxTextExtractor: Extraction error: #{inspect(error)}")
        {:error, {:extraction_exception, inspect(error)}}
    end
  end

  defp extract_text_from_docx_with_options(docx_content, opts) do
    case :zip.unzip(docx_content, [:memory]) do
      {:ok, files} ->
        include_headers_footers = Keyword.get(opts, :include_headers_footers, true)
        include_comments = Keyword.get(opts, :include_comments, false)
        preserve_structure = Keyword.get(opts, :preserve_structure, false)
        extract_tables = Keyword.get(opts, :extract_tables, true)
        
        # Extract different components based on options
        text_parts = []
        
        # Main document text
        document_text = extract_text_from_document_xml(files, %{
          preserve_structure: preserve_structure,
          extract_tables: extract_tables
        })
        text_parts = [document_text | text_parts]
        
        # Headers and footers
        if include_headers_footers do
          headers_footers_text = extract_text_from_headers_footers(files)
          text_parts = [headers_footers_text | text_parts]
        end
        
        # Comments
        if include_comments do
          comments_text = extract_text_from_comments(files)
          text_parts = [comments_text | text_parts]
        end
        
        combined_text = combine_extracted_text(Enum.reverse(text_parts))
        metadata = extract_metadata_from_zip_files(files)
        
        {:ok, combined_text, metadata}
        
      {:error, reason} ->
        {:error, {:zip_extraction_failed, reason}}
    end
  end

  defp extract_docx_metadata(docx_content) do
    case :zip.unzip(docx_content, [:memory]) do
      {:ok, files} ->
        metadata = extract_metadata_from_zip_files(files)
        {:ok, metadata}
        
      {:error, reason} ->
        {:error, {:metadata_extraction_failed, reason}}
    end
  end

  defp extract_text_from_document_xml(files, opts \\ %{}) do
    # Find word/document.xml
    case find_file_content(files, "word/document.xml") do
      {:ok, xml_content} ->
        extract_text_from_xml(xml_content, opts)
        
      {:error, _reason} ->
        ""
    end
  end

  defp extract_text_from_headers_footers(files) do
    header_footer_files = ["word/header.xml", "word/footer.xml", "word/header1.xml", "word/footer1.xml"]
    
    header_footer_files
    |> Enum.map(fn filename ->
      case find_file_content(files, filename) do
        {:ok, xml_content} ->
          extract_text_from_xml(xml_content)
        {:error, _reason} ->
          ""
      end
    end)
    |> Enum.filter(&(String.length(&1) > 0))
    |> Enum.join("\n\n")
  end

  defp extract_text_from_comments(files) do
    case find_file_content(files, "word/comments.xml") do
      {:ok, xml_content} ->
        extract_text_from_xml(xml_content)
      {:error, _reason} ->
        ""
    end
  end

  defp extract_text_from_xml(xml_content, opts \\ %{}) do
    # Tank Building Stage 2: Basic XML text extraction
    # Remove XML tags and extract text content
    
    try do
      # Extract text from <w:t> tags (Word text elements)
      text_elements = xml_content
      |> String.split(~r/<w:t[^>]*>/)
      |> Enum.drop(1)  # Remove first element (before any <w:t> tag)
      |> Enum.map(fn element ->
        # Get text before closing </w:t> tag
        element
        |> String.split("</w:t>")
        |> List.first()
        |> decode_xml_entities()
      end)
      |> Enum.filter(&(String.length(&1) > 0))
      
      preserve_structure = Map.get(opts, :preserve_structure, false)
      
      if preserve_structure do
        # Preserve paragraph structure with double newlines
        text_elements
        |> Enum.join(" ")
        |> String.replace(~r/<w:p[^>]*>/, "\n\n")
        |> clean_extracted_text()
      else
        # Simple text joining
        text_elements
        |> Enum.join(" ")
        |> clean_extracted_text()
      end
      
    rescue
      _error ->
        # Fallback: simple tag removal
        xml_content
        |> String.replace(~r/<[^>]*>/, " ")
        |> String.replace(~r/\s+/, " ")
        |> String.trim()
    end
  end

  defp find_file_content(files, target_filename) do
    case Enum.find(files, fn {filename, _content} ->
      List.to_string(filename) == target_filename
    end) do
      {_filename, content} ->
        {:ok, List.to_string(content)}
      nil ->
        {:error, :file_not_found}
    end
  end

  defp decode_xml_entities(text) do
    text
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&amp;", "&")
    |> String.replace("&quot;", "\"")
    |> String.replace("&apos;", "'")
  end

  defp clean_extracted_text(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp combine_extracted_text(text_parts) do
    text_parts
    |> Enum.filter(&(String.length(&1) > 0))
    |> Enum.join("\n\n")
    |> String.trim()
  end

  defp extract_metadata_from_zip_files(files) do
    # Extract metadata from core.xml and app.xml
    core_metadata = extract_core_properties(files)
    app_metadata = extract_app_properties(files)
    
    %{
      document_properties: core_metadata,
      application_properties: app_metadata,
      file_count: length(files),
      docx_files: Enum.map(files, fn {filename, _content} -> 
        List.to_string(filename) 
      end),
      main_document_size: get_file_size(files, "word/document.xml"),
      extraction_method: "native_elixir_zip_xml",
      extracted_at: DateTime.utc_now(),
      zip_structure_valid: true
    }
  end

  defp extract_core_properties(files) do
    case find_file_content(files, "docProps/core.xml") do
      {:ok, xml_content} ->
        %{
          title: extract_xml_property(xml_content, "dc:title"),
          creator: extract_xml_property(xml_content, "dc:creator"),
          subject: extract_xml_property(xml_content, "dc:subject"),
          description: extract_xml_property(xml_content, "dc:description"),
          keywords: extract_xml_property(xml_content, "cp:keywords"),
          created: extract_xml_property(xml_content, "dcterms:created"),
          modified: extract_xml_property(xml_content, "dcterms:modified")
        }
      {:error, _reason} ->
        %{title: "", creator: "", subject: "", description: "", keywords: "", created: nil, modified: nil}
    end
  end

  defp extract_app_properties(files) do
    case find_file_content(files, "docProps/app.xml") do
      {:ok, xml_content} ->
        %{
          application: extract_xml_property(xml_content, "Application"),
          doc_security: extract_xml_property(xml_content, "DocSecurity"),
          lines: extract_xml_property(xml_content, "Lines"),
          paragraphs: extract_xml_property(xml_content, "Paragraphs"),
          scale_crop: extract_xml_property(xml_content, "ScaleCrop"),
          total_time: extract_xml_property(xml_content, "TotalTime")
        }
      {:error, _reason} ->
        %{application: "", doc_security: "", lines: "", paragraphs: "", scale_crop: "", total_time: ""}
    end
  end

  defp extract_xml_property(xml_content, property_name) do
    # Simple regex extraction for XML properties
    pattern = ~r/<#{Regex.escape(property_name)}[^>]*>([^<]*)<\/#{Regex.escape(property_name)}>/
    
    case Regex.run(pattern, xml_content) do
      [_full, value] -> String.trim(value)
      nil -> ""
    end
  end

  defp get_file_size(files, filename) do
    case Enum.find(files, fn {file, _content} ->
      List.to_string(file) == filename
    end) do
      {_filename, content} ->
        byte_size(content)
      nil ->
        0
    end
  end

  # AtomicComponent Behavior Implementation

  @impl MultiFormatConverter.AtomicComponent
  def component_id, do: "3.3"

  @impl MultiFormatConverter.AtomicComponent  
  def component_name, do: "DocxTextExtractor"

  @impl MultiFormatConverter.AtomicComponent
  def component_responsibilities do
    ["extract_text_content_from_docx_files", "extract_docx_metadata", "parse_zip_xml_structure"]
  end

  @impl MultiFormatConverter.AtomicComponent
  def component_inputs do
    ["docx_content: binary"]
  end

  @impl MultiFormatConverter.AtomicComponent
  def component_outputs do
    ["text: string", "metadata: map"]
  end

  @impl MultiFormatConverter.AtomicComponent
  def component_dependencies do
    [":zip"]  # Depends on Erlang's built-in ZIP library
  end

  @impl MultiFormatConverter.AtomicComponent
  def run_component_tests do
    # Use the real verification test framework
    MultiFormatConverter.TestFramework.test_atomic_component(__MODULE__, component_id())
  end

  @impl MultiFormatConverter.AtomicComponent
  def verify_blockchain_signature(signature) do
    MultiFormatConverter.TestFramework.verify_blockchain_test_results(component_id(), signature)
  end

  @impl MultiFormatConverter.AtomicComponent
  def get_component_metadata do
    base_metadata = %{
      id: component_id(),
      name: component_name(),
      responsibilities: component_responsibilities(),
      inputs: component_inputs(),
      outputs: component_outputs(),
      dependencies: component_dependencies(),
      atomic: true,
      blockchain_verified: true,
      tank_building_stage: "stage_2_extend"
    }
    
    Map.merge(base_metadata, %{
      docx_capabilities: [
        "text_extraction",
        "metadata_extraction", 
        "zip_structure_parsing",
        "xml_content_extraction",
        "headers_footers_support",
        "comments_extraction",
        "table_extraction"
      ],
      supported_docx_files: @docx_xml_files,
      parsing_methods: ["zip_extraction", "xml_parsing", "regex_extraction"],
      max_file_size_bytes: @max_docx_size_bytes,
      stage_2_extension: true,
      native_implementation: true,
      zip_based: true
    })
  end
end