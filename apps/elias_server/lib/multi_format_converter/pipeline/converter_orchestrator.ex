defmodule MultiFormatConverter.Pipeline.ConverterOrchestrator do
  @moduledoc """
  Component Pipeline Orchestrator: Integrates all atomic components
  
  RESPONSIBILITY: Orchestrate atomic components into complete conversion pipeline
  
  Based on Tank Building methodology:
  - Stage 2: Extend - Integrate all atomic components without breaking Stage 1
  - Pipeline pattern: Connect components in proper sequence
  - Error handling: Graceful degradation at each step
  - Blockchain verification: End-to-end test result verification
  
  Component Integration Order:
  1. FileValidator (1.2) - Validate input file
  2. FileReader (1.1) - Read file content
  3. FormatDetector (2.1) - Identify format
  4. Content Extractors (3.1-3.3) - Extract text based on format
  5. OutputWriter (1.3) - Write markdown output
  
  Tank Building Stage 2: Complete pipeline with all Stage 1 + Stage 2 components
  """
  
  require Logger

  use MultiFormatConverter.AtomicComponent

  # Import all atomic components
  alias MultiFormatConverter.FileOperations.{FileReader, FileValidator, OutputWriter}
  alias MultiFormatConverter.FormatDetection.FormatDetector
  alias MultiFormatConverter.ContentExtraction.{PdfTextExtractor, RtfTextExtractor, DocxTextExtractor}

  # Pipeline configuration
  @pipeline_timeout 120_000  # 2 minutes for complete conversion
  @supported_formats [:pdf, :rtf, :docx, :txt, :html, :xml]
  @output_format :markdown

  # Public API - Pipeline Orchestration Interface

  @doc """
  Convert file to markdown using complete atomic component pipeline
  
  Input: input_path (string) - Path to input file
         output_path (string) - Path for markdown output
  Output: {:ok, conversion_result} | {:error, reason}
  
  PIPELINE RESPONSIBILITY: Orchestrate all components for complete conversion
  """
  def convert_file_to_markdown(input_path, output_path) 
      when is_binary(input_path) and is_binary(output_path) do
    Logger.info("ConverterOrchestrator: Starting conversion pipeline")
    Logger.info("  Input: #{input_path}")
    Logger.info("  Output: #{output_path}")
    
    pipeline_start_time = System.monotonic_time(:millisecond)
    
    result = with_timeout(@pipeline_timeout, fn ->
      execute_conversion_pipeline(input_path, output_path)
    end)
    
    pipeline_end_time = System.monotonic_time(:millisecond)
    pipeline_duration = pipeline_end_time - pipeline_start_time
    
    case result do
      {:ok, conversion_result} ->
        Logger.info("ConverterOrchestrator: Pipeline completed successfully in #{pipeline_duration}ms")
        {:ok, Map.put(conversion_result, :pipeline_duration_ms, pipeline_duration)}
        
      {:error, reason} ->
        Logger.error("ConverterOrchestrator: Pipeline failed after #{pipeline_duration}ms: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def convert_file_to_markdown(invalid_input, output_path) when not is_binary(invalid_input) do
    Logger.error("ConverterOrchestrator: Invalid input path type: #{inspect(invalid_input)}")
    {:error, :invalid_input_path_type}
  end

  def convert_file_to_markdown(input_path, invalid_output) when not is_binary(invalid_output) do
    Logger.error("ConverterOrchestrator: Invalid output path type: #{inspect(invalid_output)}")
    {:error, :invalid_output_path_type}
  end

  @doc """
  Convert with custom pipeline options
  
  Options:
  - format_hint: atom - Hint for format detection (bypasses detection if confident)
  - extraction_options: keyword - Options passed to content extractors
  - validation_options: keyword - Custom validation limits
  - output_options: keyword - Output formatting options
  """
  def convert_file_with_options(input_path, output_path, opts \\ []) 
      when is_binary(input_path) and is_binary(output_path) do
    Logger.info("ConverterOrchestrator: Starting conversion with options: #{inspect(opts)}")
    
    result = execute_conversion_pipeline_with_options(input_path, output_path, opts)
    
    case result do
      {:ok, conversion_result} ->
        Logger.info("ConverterOrchestrator: Custom pipeline completed successfully")
        {:ok, conversion_result}
        
      {:error, reason} ->
        Logger.error("ConverterOrchestrator: Custom pipeline failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get pipeline status and component health
  
  Returns status of all atomic components and pipeline readiness
  """
  def get_pipeline_status do
    components = [
      {FileValidator, "1.2", "FileValidator"},
      {FileReader, "1.1", "FileReader"}, 
      {FormatDetector, "2.1", "FormatDetector"},
      {PdfTextExtractor, "3.1", "PdfTextExtractor"},
      {RtfTextExtractor, "3.2", "RtfTextExtractor"},
      {DocxTextExtractor, "3.3", "DocxTextExtractor"},
      {OutputWriter, "1.3", "OutputWriter"}
    ]
    
    component_status = Enum.map(components, fn {module, id, name} ->
      try do
        metadata = module.get_component_metadata()
        %{
          id: id,
          name: name,
          module: module,
          status: :available,
          atomic: Map.get(metadata, :atomic, false),
          blockchain_verified: Map.get(metadata, :blockchain_verified, false),
          stage: Map.get(metadata, :tank_building_stage, "unknown")
        }
      rescue
        error ->
          %{
            id: id,
            name: name,
            module: module,
            status: :error,
            error: inspect(error)
          }
      end
    end)
    
    available_components = Enum.count(component_status, &(&1.status == :available))
    total_components = length(component_status)
    
    %{
      pipeline_ready: available_components == total_components,
      total_components: total_components,
      available_components: available_components,
      supported_formats: @supported_formats,
      output_format: @output_format,
      components: component_status,
      pipeline_timeout_ms: @pipeline_timeout
    }
  end

  @doc """
  Test complete pipeline with sample files
  
  Runs end-to-end integration test of entire pipeline
  """
  def test_complete_pipeline do
    Logger.info("ConverterOrchestrator: Running complete pipeline integration test")
    
    # Test with each supported format if sample files exist
    test_results = @supported_formats
    |> Enum.map(fn format ->
      test_pipeline_with_format(format)
    end)
    |> Enum.filter(&match?({:ok, _}, &1))
    
    success_count = length(test_results)
    total_formats = length(@supported_formats)
    
    %{
      integration_test_passed: success_count > 0,
      formats_tested: total_formats,
      formats_successful: success_count,
      test_results: test_results,
      pipeline_status: get_pipeline_status()
    }
  end

  # Private Pipeline Implementation

  defp execute_conversion_pipeline(input_path, output_path) do
    # Stage 1: File Validation (Component 1.2)
    with {:ok, :validated} <- validate_input_file(input_path),
         # Stage 2: File Reading (Component 1.1) 
         {:ok, file_content, file_size} <- read_input_file(input_path),
         # Stage 3: Format Detection (Component 2.1)
         {:ok, detected_format} <- detect_file_format(file_content),
         # Stage 4: Content Extraction (Components 3.1-3.3)
         {:ok, extracted_text, extraction_metadata} <- extract_text_content(file_content, detected_format),
         # Stage 5: Markdown Generation
         {:ok, markdown_content} <- generate_markdown_output(extracted_text, extraction_metadata),
         # Stage 6: Output Writing (Component 1.3)
         {:ok, bytes_written} <- write_markdown_output(markdown_content, output_path) do
      
      # Success - return comprehensive conversion result
      {:ok, %{
        input_file: input_path,
        output_file: output_path,
        file_size_bytes: file_size,
        detected_format: detected_format,
        extracted_text_length: String.length(extracted_text),
        markdown_content_length: String.length(markdown_content),
        output_bytes_written: bytes_written,
        extraction_metadata: extraction_metadata,
        pipeline_stages_completed: 6,
        conversion_successful: true
      }}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_conversion_pipeline_with_options(input_path, output_path, opts) do
    format_hint = Keyword.get(opts, :format_hint)
    extraction_options = Keyword.get(opts, :extraction_options, [])
    validation_options = Keyword.get(opts, :validation_options, [])
    
    # Execute pipeline with custom options
    with {:ok, :validated} <- validate_input_file_with_options(input_path, validation_options),
         {:ok, file_content, file_size} <- read_input_file(input_path),
         {:ok, detected_format} <- detect_file_format_with_hint(file_content, format_hint),
         {:ok, extracted_text, extraction_metadata} <- extract_text_content_with_options(file_content, detected_format, extraction_options),
         {:ok, markdown_content} <- generate_markdown_output(extracted_text, extraction_metadata),
         {:ok, bytes_written} <- write_markdown_output(markdown_content, output_path) do
      
      {:ok, %{
        input_file: input_path,
        output_file: output_path,
        file_size_bytes: file_size,
        detected_format: detected_format,
        format_hint_used: format_hint,
        extracted_text_length: String.length(extracted_text),
        markdown_content_length: String.length(markdown_content),
        output_bytes_written: bytes_written,
        extraction_metadata: extraction_metadata,
        extraction_options: extraction_options,
        conversion_successful: true
      }}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Pipeline Stage Functions

  defp validate_input_file(input_path) do
    Logger.debug("ConverterOrchestrator: Stage 1 - File Validation")
    
    case FileValidator.validate_file(input_path) do
      {:ok, true, nil} ->
        Logger.debug("  ✅ File validation passed")
        {:ok, :validated}
        
      {:ok, false, error_reason} ->
        Logger.error("  ❌ File validation failed: #{error_reason}")
        {:error, {:validation_failed, error_reason}}
        
      {:error, reason} ->
        Logger.error("  ❌ File validation error: #{reason}")
        {:error, {:validation_error, reason}}
    end
  end

  defp validate_input_file_with_options(input_path, validation_options) do
    case Keyword.get(validation_options, :custom_limits) do
      {min_size, max_size} ->
        case FileValidator.validate_file_with_limits(input_path, min_size, max_size) do
          {:ok, true, nil} -> {:ok, :validated}
          {:ok, false, reason} -> {:error, {:validation_failed, reason}}
          {:error, reason} -> {:error, {:validation_error, reason}}
        end
      nil ->
        validate_input_file(input_path)
    end
  end

  defp read_input_file(input_path) do
    Logger.debug("ConverterOrchestrator: Stage 2 - File Reading")
    
    case FileReader.read_file(input_path) do
      {:ok, content, size} ->
        Logger.debug("  ✅ File read successfully (#{size} bytes)")
        {:ok, content, size}
        
      {:error, reason} ->
        Logger.error("  ❌ File reading failed: #{reason}")
        {:error, {:file_read_failed, reason}}
    end
  end

  defp detect_file_format(file_content) do
    Logger.debug("ConverterOrchestrator: Stage 3 - Format Detection")
    
    case FormatDetector.detect_format(file_content) do
      {:ok, format} ->
        Logger.debug("  ✅ Format detected: #{format}")
        
        if format in @supported_formats do
          {:ok, format}
        else
          Logger.warn("  ⚠️ Format #{format} not supported for extraction")
          {:error, {:unsupported_format, format}}
        end
        
      {:error, reason} ->
        Logger.error("  ❌ Format detection failed: #{reason}")
        {:error, {:format_detection_failed, reason}}
    end
  end

  defp detect_file_format_with_hint(file_content, format_hint) do
    if format_hint && format_hint in @supported_formats do
      Logger.debug("ConverterOrchestrator: Using format hint: #{format_hint}")
      {:ok, format_hint}
    else
      detect_file_format(file_content)
    end
  end

  defp extract_text_content(file_content, format) do
    Logger.debug("ConverterOrchestrator: Stage 4 - Text Extraction (#{format})")
    
    extractor_result = case format do
      :pdf ->
        PdfTextExtractor.extract_text(file_content)
      :rtf ->
        RtfTextExtractor.extract_text(file_content)
      :docx ->
        DocxTextExtractor.extract_text(file_content)
      :txt ->
        # For plain text, just return the content
        {:ok, file_content, %{format: :txt, extraction_method: "direct"}}
      :html ->
        # Basic HTML text extraction (Tank Building Stage 2 - extend as needed)
        html_text = extract_basic_html_text(file_content)
        {:ok, html_text, %{format: :html, extraction_method: "basic_html_parser"}}
      :xml ->
        # Basic XML text extraction
        xml_text = extract_basic_xml_text(file_content)
        {:ok, xml_text, %{format: :xml, extraction_method: "basic_xml_parser"}}
      _ ->
        {:error, {:unsupported_extraction_format, format}}
    end
    
    case extractor_result do
      {:ok, text, metadata} ->
        Logger.debug("  ✅ Text extraction successful (#{String.length(text)} chars)")
        {:ok, text, metadata}
        
      {:error, reason} ->
        Logger.error("  ❌ Text extraction failed: #{inspect(reason)}")
        {:error, {:text_extraction_failed, reason}}
    end
  end

  defp extract_text_content_with_options(file_content, format, extraction_options) do
    # Pass options to extractors that support them
    case format do
      :pdf ->
        PdfTextExtractor.extract_text_with_options(file_content, extraction_options)
      :rtf ->
        RtfTextExtractor.extract_text_with_options(file_content, extraction_options)
      :docx ->
        DocxTextExtractor.extract_text_with_options(file_content, extraction_options)
      _ ->
        extract_text_content(file_content, format)
    end
  end

  defp generate_markdown_output(extracted_text, extraction_metadata) do
    Logger.debug("ConverterOrchestrator: Stage 5 - Markdown Generation")
    
    # Tank Building Stage 2: Basic markdown generation
    markdown_content = """
    # Converted Document

    **Source Format:** #{Map.get(extraction_metadata, :format, "unknown")}  
    **Extraction Method:** #{Map.get(extraction_metadata, :extraction_method, "unknown")}  
    **Extracted At:** #{Map.get(extraction_metadata, :extracted_at, DateTime.utc_now())}

    ---

    #{extracted_text}

    ---

    *Converted using Multi-Format Converter (Tank Building Stage 2)*
    """
    
    Logger.debug("  ✅ Markdown generated (#{String.length(markdown_content)} chars)")
    {:ok, markdown_content}
  end

  defp write_markdown_output(markdown_content, output_path) do
    Logger.debug("ConverterOrchestrator: Stage 6 - Output Writing")
    
    case OutputWriter.write_output(markdown_content, output_path) do
      {:ok, bytes_written} ->
        Logger.debug("  ✅ Output written successfully (#{bytes_written} bytes)")
        {:ok, bytes_written}
        
      {:error, reason} ->
        Logger.error("  ❌ Output writing failed: #{reason}")
        {:error, {:output_write_failed, reason}}
    end
  end

  # Utility Functions

  defp extract_basic_html_text(html_content) do
    # Basic HTML text extraction - remove tags
    html_content
    |> String.replace(~r/<script[^>]*>.*?<\/script>/s, "")
    |> String.replace(~r/<style[^>]*>.*?<\/style>/s, "")
    |> String.replace(~r/<[^>]*>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp extract_basic_xml_text(xml_content) do
    # Basic XML text extraction - remove tags and CDATA
    xml_content
    |> String.replace(~r/<!\[CDATA\[.*?\]\]>/s, "")
    |> String.replace(~r/<!--.*?-->/s, "")
    |> String.replace(~r/<[^>]*>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp test_pipeline_with_format(format) do
    # Test if sample files exist and pipeline works for format
    sample_file = "apps/elias_server/test/fixtures/converter_test_files/sample.#{format}"
    output_file = "/tmp/pipeline_test_#{format}.md"
    
    if File.exists?(sample_file) do
      case convert_file_to_markdown(sample_file, output_file) do
        {:ok, result} ->
          File.rm(output_file)  # Cleanup
          {:ok, %{format: format, test: :passed, result: result}}
        {:error, reason} ->
          {:error, %{format: format, test: :failed, reason: reason}}
      end
    else
      {:skip, %{format: format, test: :skipped, reason: :no_sample_file}}
    end
  end

  defp with_timeout(timeout_ms, fun) do
    task = Task.async(fun)
    
    try do
      Task.await(task, timeout_ms)
    catch
      :exit, {:timeout, _} ->
        Task.shutdown(task, :brutal_kill)
        {:error, :pipeline_timeout}
    end
  end

  # AtomicComponent Behavior Implementation

  @impl MultiFormatConverter.AtomicComponent
  def component_id, do: "0.1"

  @impl MultiFormatConverter.AtomicComponent  
  def component_name, do: "ConverterOrchestrator"

  @impl MultiFormatConverter.AtomicComponent
  def component_responsibilities do
    ["orchestrate_atomic_components", "execute_conversion_pipeline", "integrate_stage_1_and_stage_2"]
  end

  @impl MultiFormatConverter.AtomicComponent
  def component_inputs do
    ["input_file_path: string", "output_file_path: string"]
  end

  @impl MultiFormatConverter.AtomicComponent
  def component_outputs do
    ["conversion_result: map", "pipeline_status: map"]
  end

  @impl MultiFormatConverter.AtomicComponent
  def component_dependencies do
    ["FileValidator:1.2", "FileReader:1.1", "FormatDetector:2.1", "PdfTextExtractor:3.1", "RtfTextExtractor:3.2", "DocxTextExtractor:3.3", "OutputWriter:1.3"]
  end

  @impl MultiFormatConverter.AtomicComponent
  def run_component_tests do
    # Run integration tests for complete pipeline
    test_complete_pipeline()
  end

  @impl MultiFormatConverter.AtomicComponent
  def verify_blockchain_signature(signature) do
    MultiFormatConverter.TestFramework.verify_blockchain_test_results(component_id(), signature)
  end

  @impl MultiFormatConverter.AtomicComponent
  def get_component_metadata do
    %{
      id: component_id(),
      name: component_name(),
      responsibilities: component_responsibilities(),
      inputs: component_inputs(),
      outputs: component_outputs(),
      dependencies: component_dependencies(),
      atomic: false,  # This is an orchestrator, not atomic
      blockchain_verified: true,
      tank_building_stage: "stage_2_extend",
      pipeline_orchestrator: true,
      supported_formats: @supported_formats,
      output_format: @output_format,
      pipeline_timeout_ms: @pipeline_timeout,
      integration_component: true
    }
  end
end