defmodule MultiFormatConverter.FormatDetection.FormatDetector do
  @moduledoc """
  Atomic Component 2.1: FormatDetector
  
  RESPONSIBILITY: Identify file format via magic bytes - ONLY format identification
  
  Based on Architect guidance:
  - Atomic granularity: One responsibility per component
  - Real testing: Test known file samples, verify format detection accuracy
  - Blockchain verification: All tests signed and submitted to Level 2 rollup
  
  Tank Building Stage 1: Brute force format detection using magic bytes
  """
  
  require Logger

  use MultiFormatConverter.AtomicComponent

  # Magic byte signatures for format detection
  @format_signatures %{
    # PDF format
    pdf: [
      <<0x25, 0x50, 0x44, 0x46>>,  # %PDF
      <<"%PDF">>
    ],
    
    # RTF format  
    rtf: [
      <<0x7B, 0x5C, 0x72, 0x74, 0x66>>,  # {\rtf
      <<"{\\rtf">>
    ],
    
    # DOCX format (ZIP-based)
    docx: [
      <<0x50, 0x4B, 0x03, 0x04>>,  # ZIP signature (DOCX is ZIP)
      <<0x50, 0x4B, 0x05, 0x06>>,  # ZIP empty archive
      <<0x50, 0x4B, 0x07, 0x08>>   # ZIP spanned archive
    ],
    
    # HTML format
    html: [
      <<"<!DOCTYPE">>,
      <<"<html">>,
      <<"<HTML">>,
      <<"<!doctype">>,
      <<0x3C, 0x68, 0x74, 0x6D, 0x6C>>,  # <html
      <<0x3C, 0x48, 0x54, 0x4D, 0x4C>>   # <HTML
    ],
    
    # XML format
    xml: [
      <<"<?xml">>,
      <<"<?XML">>,
      <<0x3C, 0x3F, 0x78, 0x6D, 0x6C>>  # <?xml
    ]
  }
  
  # Minimum bytes needed for reliable detection
  @min_detection_bytes 512

  # Public API - Atomic Component Interface

  @doc """
  Detect file format using magic bytes analysis
  
  Input: file_content (binary) - File content to analyze
  Output: {:ok, format} | {:error, reason}
         format: :pdf | :rtf | :docx | :txt | :html | :xml | :unknown
  
  ATOMIC RESPONSIBILITY: ONLY format identification, no content processing
  """
  def detect_format(file_content) when is_binary(file_content) do
    Logger.debug("FormatDetector: Analyzing #{byte_size(file_content)} bytes for format detection")
    
    if byte_size(file_content) < 4 do
      Logger.warn("FormatDetector: File too small for reliable format detection")
      {:ok, :unknown}
    else
      # Get first chunk for magic byte analysis
      detection_chunk = binary_part(file_content, 0, min(byte_size(file_content), @min_detection_bytes))
      
      format = detect_format_by_magic_bytes(detection_chunk)
      
      # If no magic bytes match, try content-based detection
      final_format = if format == :unknown do
        detect_format_by_content_analysis(detection_chunk)
      else
        format
      end
      
      Logger.debug("FormatDetector: Detected format: #{final_format}")
      {:ok, final_format}
    end
  end

  def detect_format(invalid_content) do
    Logger.error("FormatDetector: Invalid content type: #{inspect(invalid_content)}")
    {:error, :invalid_content_type}
  end

  @doc """
  Detect format with confidence score
  
  Returns format and confidence level for the detection
  """
  def detect_format_with_confidence(file_content) when is_binary(file_content) do
    case detect_format(file_content) do
      {:ok, format} ->
        confidence = calculate_detection_confidence(file_content, format)
        {:ok, format, confidence}
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Check if file content matches specific format
  
  Useful for validation of expected formats
  """
  def is_format?(file_content, expected_format) 
      when is_binary(file_content) and is_atom(expected_format) do
    case detect_format(file_content) do
      {:ok, detected_format} -> detected_format == expected_format
      {:error, _} -> false
    end
  end

  @doc """
  Get all supported formats
  
  Returns list of formats this detector can identify
  """
  def supported_formats do
    Map.keys(@format_signatures) ++ [:txt, :unknown]
  end

  @doc """
  Get detailed format analysis
  
  Returns comprehensive analysis of file format characteristics
  """
  def analyze_format(file_content) when is_binary(file_content) do
    case detect_format(file_content) do
      {:ok, format} ->
        analysis = %{
          detected_format: format,
          file_size_bytes: byte_size(file_content),
          magic_bytes_found: find_matching_magic_bytes(file_content, format),
          content_characteristics: analyze_content_characteristics(file_content),
          detection_confidence: calculate_detection_confidence(file_content, format)
        }
        {:ok, analysis}
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private Implementation Functions

  defp detect_format_by_magic_bytes(content) do
    Enum.find_value(@format_signatures, :unknown, fn {format, signatures} ->
      if Enum.any?(signatures, &String.starts_with?(content, &1)) do
        format
      else
        nil
      end
    end)
  end

  defp detect_format_by_content_analysis(content) do
    # Additional heuristics for formats without clear magic bytes
    
    cond do
      # Check for DOCX by looking for ZIP + Office content
      is_docx_content?(content) ->
        :docx
        
      # Check for HTML by looking for common HTML patterns
      is_html_content?(content) ->
        :html
        
      # Check for XML patterns
      is_xml_content?(content) ->
        :xml
        
      # Check if appears to be plain text
      is_plain_text?(content) ->
        :txt
        
      # Default to unknown
      true ->
        :unknown
    end
  end

  defp is_docx_content?(content) do
    # DOCX files are ZIP archives containing specific Office files
    String.starts_with?(content, "PK") and 
    (String.contains?(content, "word/") or 
     String.contains?(content, "docProps/") or
     String.contains?(content, "[Content_Types].xml"))
  end

  defp is_html_content?(content) do
    # Look for common HTML patterns
    lower_content = String.downcase(content)
    
    Enum.any?([
      String.contains?(lower_content, "<html"),
      String.contains?(lower_content, "<head"),
      String.contains?(lower_content, "<body"),
      String.contains?(lower_content, "</html>"),
      String.contains?(lower_content, "<!doctype")
    ])
  end

  defp is_xml_content?(content) do
    # Look for XML declaration or common XML patterns
    String.starts_with?(String.trim_leading(content), "<?xml") or
    String.starts_with?(String.trim_leading(content), "<") and String.contains?(content, "/>")
  end

  defp is_plain_text?(content) do
    # Check if content is mostly printable ASCII
    printable_ratio = content
    |> :binary.bin_to_list()
    |> Enum.count(fn byte -> byte >= 32 and byte <= 126 or byte in [9, 10, 13] end)
    |> Kernel./(byte_size(content))
    
    printable_ratio > 0.8
  end

  defp calculate_detection_confidence(content, format) do
    case format do
      :unknown -> 0.0
      :txt -> calculate_text_confidence(content)
      _ -> calculate_format_confidence(content, format)
    end
  end

  defp calculate_text_confidence(content) do
    # For plain text, confidence based on printable character ratio
    printable_count = content
    |> :binary.bin_to_list()
    |> Enum.count(fn byte -> byte >= 32 and byte <= 126 or byte in [9, 10, 13] end)
    
    if byte_size(content) > 0 do
      min(printable_count / byte_size(content), 1.0)
    else
      0.0
    end
  end

  defp calculate_format_confidence(content, format) do
    # High confidence for magic byte matches
    signatures = Map.get(@format_signatures, format, [])
    
    if Enum.any?(signatures, &String.starts_with?(content, &1)) do
      0.95  # High confidence for magic byte match
    else
      0.7   # Lower confidence for content-based detection
    end
  end

  defp find_matching_magic_bytes(content, format) do
    signatures = Map.get(@format_signatures, format, [])
    
    Enum.filter(signatures, fn signature ->
      String.starts_with?(content, signature)
    end)
  end

  defp analyze_content_characteristics(content) do
    %{
      size_bytes: byte_size(content),
      first_16_bytes: binary_part(content, 0, min(16, byte_size(content))) |> Base.encode16(),
      contains_null_bytes: String.contains?(content, <<0>>),
      newline_count: content |> String.graphemes() |> Enum.count(&(&1 == "\n")),
      binary_ratio: calculate_binary_ratio(content)
    }
  end

  defp calculate_binary_ratio(content) do
    non_printable_count = content
    |> :binary.bin_to_list()
    |> Enum.count(fn byte -> byte < 32 and byte not in [9, 10, 13] end)
    
    if byte_size(content) > 0 do
      non_printable_count / byte_size(content)
    else
      0.0
    end
  end

  # AtomicComponent Behavior Implementation

  @impl MultiFormatConverter.AtomicComponent
  def component_id, do: "2.1"

  @impl MultiFormatConverter.AtomicComponent  
  def component_name, do: "FormatDetector"

  @impl MultiFormatConverter.AtomicComponent
  def component_responsibilities do
    ["identify_file_format_via_magic_bytes", "content_based_format_detection"]
  end

  @impl MultiFormatConverter.AtomicComponent
  def component_inputs do
    ["file_content: binary"]
  end

  @impl MultiFormatConverter.AtomicComponent
  def component_outputs do
    ["format: :pdf | :rtf | :docx | :txt | :html | :xml | :unknown"]
  end

  @impl MultiFormatConverter.AtomicComponent
  def component_dependencies do
    []  # No dependencies - this is a leaf atomic component
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
      tank_building_stage: "stage_1_brute_force"
    }
    
    Map.merge(base_metadata, %{
      supported_formats: supported_formats(),
      detection_methods: ["magic_bytes", "content_analysis", "heuristics"],
      magic_byte_signatures: map_size(@format_signatures),
      minimum_detection_bytes: @min_detection_bytes
    })
  end
end