defmodule Tiki.SpecLoader do
  @moduledoc """
  Tiki Specification Loader and Validator
  
  Handles loading, parsing, and validation of .tiki specification files
  following Architect's guidance for hierarchical specification system.
  
  Features:
  - YAML parsing with error handling
  - Code reference validation (file paths, line ranges)  
  - Dependency validation and graph building
  - ETS caching for performance
  - Module existence verification
  """
  
  require Logger
  
  @spec_dir Path.join([File.cwd!(), "apps", "elias_server", "priv", "manager_specs"])
  
  # Public API
  
  def load_spec(spec_file, cache_table \\ nil) do
    # Check cache first (per Architect guidance)
    case cache_table && lookup_cached_spec(spec_file, cache_table) do
      {:ok, cached_spec} ->
        Logger.debug("📋 Tiki.SpecLoader: Cache hit for #{spec_file}")
        {:ok, cached_spec}
        
      _ ->
        # Load from file
        case load_spec_from_file(spec_file) do
          {:ok, spec} ->
            # Cache if table provided
            if cache_table, do: cache_spec(spec_file, spec, cache_table)
            {:ok, spec}
            
          error ->
            error
        end
    end
  end
  
  def validate_spec(spec_file, cache_table \\ nil) do
    case load_spec(spec_file, cache_table) do
      {:ok, spec} ->
        validation_results = run_comprehensive_validation(spec, spec_file)
        {:ok, validation_results}
        
      {:error, reason} ->
        {:error, [%{type: :load_error, message: reason}]}
    end
  end
  
  def get_all_specs(cache_table \\ nil) do
    case File.ls(@spec_dir) do
      {:ok, files} ->
        tiki_files = Enum.filter(files, &String.ends_with?(&1, ".tiki"))
        
        specs = Enum.reduce(tiki_files, %{}, fn file, acc ->
          case load_spec(file, cache_table) do
            {:ok, spec} -> Map.put(acc, file, spec)
            {:error, _reason} -> acc  # Skip invalid specs
          end
        end)
        
        {:ok, specs}
        
      {:error, reason} ->
        {:error, "Cannot read spec directory: #{reason}"}
    end
  end
  
  # Private Functions - Loading
  
  defp load_spec_from_file(spec_file) do
    spec_path = resolve_spec_path(spec_file)
    
    case File.read(spec_path) do
      {:ok, content} ->
        parse_tiki_content(content, spec_file)
        
      {:error, :enoent} ->
        {:error, "Spec file not found: #{spec_path}"}
        
      {:error, reason} ->
        {:error, "Cannot read spec file: #{reason}"}
    end
  end
  
  defp resolve_spec_path(spec_file) do
    if Path.extname(spec_file) == ".tiki" do
      Path.join(@spec_dir, spec_file)
    else
      Path.join(@spec_dir, spec_file <> ".tiki")
    end
  end
  
  defp parse_tiki_content(content, spec_file) do
    case YamlElixir.read_from_string(content) do
      {:ok, parsed_yaml} ->
        # Add metadata
        spec = Map.put(parsed_yaml, "_metadata", %{
          file: spec_file,
          loaded_at: DateTime.utc_now(),
          checksum: calculate_checksum(content)
        })
        
        {:ok, spec}
        
      {:error, reason} ->
        {:error, "YAML parsing failed: #{inspect(reason)}"}
    end
  end
  
  defp calculate_checksum(content) do
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end
  
  # Private Functions - Caching
  
  defp lookup_cached_spec(spec_file, cache_table) do
    case :ets.lookup(cache_table, spec_file) do
      [{^spec_file, spec, cached_at}] ->
        # Check if cache is still valid (5 minute TTL)
        cache_age = DateTime.diff(DateTime.utc_now(), cached_at, :second)
        if cache_age < 300 do
          {:ok, spec}
        else
          :cache_expired
        end
        
      [] ->
        :cache_miss
    end
  end
  
  defp cache_spec(spec_file, spec, cache_table) do
    :ets.insert(cache_table, {spec_file, spec, DateTime.utc_now()})
  end
  
  # Private Functions - Validation
  
  defp run_comprehensive_validation(spec, spec_file) do
    validations = [
      validate_required_fields(spec),
      validate_metadata_format(spec),
      validate_children_structure(spec),
      validate_code_references(spec),
      validate_module_references(spec),
      validate_dependencies(spec),
      validate_performance_expectations(spec),
      validate_cross_references(spec)
    ]
    
    # Flatten all validation results
    all_results = List.flatten(validations)
    
    # Categorize results
    errors = Enum.filter(all_results, &(&1.type == :error))
    warnings = Enum.filter(all_results, &(&1.type == :warning))
    info = Enum.filter(all_results, &(&1.type == :info))
    
    %{
      spec_file: spec_file,
      total_checks: length(all_results),
      errors: errors,
      warnings: warnings,
      info: info,
      valid: length(errors) == 0,
      validated_at: DateTime.utc_now()
    }
  end
  
  defp validate_required_fields(spec) do
    required_fields = ["id", "name", "version"]
    
    required_fields
    |> Enum.map(fn field ->
      if Map.has_key?(spec, field) do
        %{type: :info, field: field, message: "Required field present"}
      else
        %{type: :error, field: field, message: "Missing required field: #{field}"}
      end
    end)
  end
  
  defp validate_metadata_format(spec) do
    case Map.get(spec, "metadata") do
      nil ->
        [%{type: :warning, field: "metadata", message: "No metadata section found"}]
        
      metadata when is_map(metadata) ->
        validate_metadata_fields(metadata)
        
      _ ->
        [%{type: :error, field: "metadata", message: "Metadata must be a map"}]
    end
  end
  
  defp validate_metadata_fields(metadata) do
    validations = []
    
    # Validate dependencies
    validations = case Map.get(metadata, "dependencies") do
      nil ->
        validations
      deps when is_list(deps) ->
        [%{type: :info, field: "dependencies", message: "#{length(deps)} dependencies found"} | validations]
      _ ->
        [%{type: :error, field: "dependencies", message: "Dependencies must be a list"} | validations]
    end
    
    # Validate performance expectations
    validations = case Map.get(metadata, "performance") do
      nil ->
        validations
      perf when is_map(perf) ->
        validate_performance_fields(perf) ++ validations
      _ ->
        [%{type: :error, field: "performance", message: "Performance must be a map"} | validations]
    end
    
    validations
  end
  
  defp validate_performance_fields(performance) do
    performance_fields = ["latency_ms", "memory_mb", "cpu_percent", "scalability"]
    
    Enum.map(performance_fields, fn field ->
      case Map.get(performance, field) do
        nil ->
          %{type: :info, field: "performance.#{field}", message: "Optional performance field not specified"}
        value when is_number(value) or is_binary(value) ->
          %{type: :info, field: "performance.#{field}", message: "Performance expectation set"}
        _ ->
          %{type: :warning, field: "performance.#{field}", message: "Invalid performance field format"}
      end
    end)
  end
  
  defp validate_children_structure(spec) do
    case Map.get(spec, "children") do
      nil ->
        [%{type: :info, field: "children", message: "No children defined (leaf node)"}]
        
      children when is_list(children) ->
        validate_children_list(children)
        
      _ ->
        [%{type: :error, field: "children", message: "Children must be a list"}]
    end
  end
  
  defp validate_children_list(children) do
    children
    |> Enum.with_index()
    |> Enum.flat_map(fn {child, index} ->
      case child do
        child_map when is_map(child_map) ->
          validate_child_node(child_map, index)
        _ ->
          [%{type: :error, field: "children[#{index}]", message: "Child must be a map"}]
      end
    end)
  end
  
  defp validate_child_node(child, index) do
    validations = []
    
    # Check required child fields
    required_child_fields = ["id", "name"]
    validations = required_child_fields
    |> Enum.reduce(validations, fn field, acc ->
      if Map.has_key?(child, field) do
        [%{type: :info, field: "children[#{index}].#{field}", message: "Required child field present"} | acc]
      else
        [%{type: :error, field: "children[#{index}].#{field}", message: "Missing required child field: #{field}"} | acc]
      end
    end)
    
    # Recursively validate nested children
    case Map.get(child, "children") do
      nil ->
        validations
      nested_children when is_list(nested_children) ->
        nested_validations = validate_children_list(nested_children)
        validations ++ nested_validations
      _ ->
        [%{type: :error, field: "children[#{index}].children", message: "Nested children must be a list"} | validations]
    end
  end
  
  defp validate_code_references(spec) do
    extract_code_refs(spec)
    |> Enum.map(&validate_code_reference/1)
  end
  
  defp extract_code_refs(spec) do
    refs = []
    
    # Check root level
    refs = case Map.get(spec, "code_ref") do
      nil -> refs
      code_ref -> [code_ref | refs]
    end
    
    # Check children recursively
    case Map.get(spec, "children") do
      nil ->
        refs
      children when is_list(children) ->
        child_refs = Enum.flat_map(children, &extract_code_refs/1)
        refs ++ child_refs
      _ ->
        refs
    end
  end
  
  defp validate_code_reference(code_ref) do
    case String.split(code_ref, ":") do
      [file_path, line_range] ->
        validate_file_and_lines(file_path, line_range, code_ref)
        
      [file_path] ->
        validate_file_exists(file_path, code_ref)
        
      _ ->
        %{type: :error, field: "code_ref", message: "Invalid code_ref format: #{code_ref}"}
    end
  end
  
  defp validate_file_and_lines(file_path, line_range, code_ref) do
    full_path = Path.join([File.cwd!(), "apps", "elias_server", file_path])
    
    case File.read(full_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")
        total_lines = length(lines)
        
        case parse_line_range(line_range) do
          {:ok, start_line, end_line} ->
            if start_line <= total_lines and end_line <= total_lines do
              %{type: :info, field: "code_ref", message: "Valid code reference: #{code_ref}"}
            else
              %{type: :error, field: "code_ref", message: "Line range #{line_range} exceeds file length #{total_lines}"}
            end
            
          {:error, reason} ->
            %{type: :error, field: "code_ref", message: "Invalid line range: #{reason}"}
        end
        
      {:error, _reason} ->
        %{type: :error, field: "code_ref", message: "File not found: #{file_path}"}
    end
  end
  
  defp validate_file_exists(file_path, code_ref) do
    full_path = Path.join([File.cwd!(), "apps", "elias_server", file_path])
    
    if File.exists?(full_path) do
      %{type: :info, field: "code_ref", message: "File exists: #{code_ref}"}
    else
      %{type: :error, field: "code_ref", message: "File not found: #{file_path}"}
    end
  end
  
  defp parse_line_range(line_range) do
    case String.split(line_range, "-") do
      [start_str, end_str] ->
        with {start_line, ""} <- Integer.parse(start_str),
             {end_line, ""} <- Integer.parse(end_str) do
          {:ok, start_line, end_line}
        else
          _ -> {:error, "Invalid line numbers"}
        end
        
      [single_line] ->
        case Integer.parse(single_line) do
          {line_num, ""} -> {:ok, line_num, line_num}
          _ -> {:error, "Invalid line number"}
        end
        
      _ ->
        {:error, "Invalid line range format"}
    end
  end
  
  defp validate_module_references(spec) do
    extract_module_refs(spec)
    |> Enum.map(&validate_module_exists/1)
  end
  
  defp extract_module_refs(spec) do
    refs = []
    
    # Check root level
    refs = case Map.get(spec, "module") do
      nil -> refs
      module_name -> [module_name | refs]
    end
    
    # Check children recursively
    case Map.get(spec, "children") do
      nil ->
        refs
      children when is_list(children) ->
        child_refs = Enum.flat_map(children, &extract_module_refs/1)
        refs ++ child_refs
      _ ->
        refs
    end
  end
  
  defp validate_module_exists(module_name) do
    try do
      module_atom = String.to_existing_atom("Elixir.#{module_name}")
      if Code.ensure_loaded?(module_atom) do
        %{type: :info, field: "module", message: "Module exists: #{module_name}"}
      else
        %{type: :warning, field: "module", message: "Module not loaded: #{module_name}"}
      end
    rescue
      ArgumentError ->
        %{type: :error, field: "module", message: "Module does not exist: #{module_name}"}
    end
  end
  
  defp validate_dependencies(spec) do
    case get_in(spec, ["metadata", "dependencies"]) do
      nil ->
        [%{type: :info, field: "dependencies", message: "No dependencies specified"}]
        
      deps when is_list(deps) ->
        Enum.map(deps, fn dep ->
          %{type: :info, field: "dependencies", message: "Dependency: #{dep}"}
        end)
        
      _ ->
        [%{type: :error, field: "dependencies", message: "Dependencies must be a list"}]
    end
  end
  
  defp validate_performance_expectations(spec) do
    case get_in(spec, ["metadata", "performance"]) do
      nil ->
        [%{type: :info, field: "performance", message: "No performance expectations specified"}]
        
      perf when is_map(perf) ->
        validate_performance_values(perf)
        
      _ ->
        [%{type: :error, field: "performance", message: "Performance expectations must be a map"}]
    end
  end
  
  defp validate_performance_values(performance) do
    Enum.map(performance, fn {key, value} ->
      case validate_performance_value(key, value) do
        :ok ->
          %{type: :info, field: "performance.#{key}", message: "Valid performance expectation: #{value}"}
        {:warning, message} ->
          %{type: :warning, field: "performance.#{key}", message: message}
        {:error, message} ->
          %{type: :error, field: "performance.#{key}", message: message}
      end
    end)
  end
  
  defp validate_performance_value("latency_ms", value) when is_number(value) and value > 0, do: :ok
  defp validate_performance_value("memory_mb", value) when is_number(value) and value > 0, do: :ok
  defp validate_performance_value("cpu_percent", value) when is_number(value) and value >= 0 and value <= 100, do: :ok
  defp validate_performance_value("scalability", value) when is_binary(value), do: :ok
  defp validate_performance_value(key, value), do: {:warning, "Unrecognized performance field: #{key} = #{value}"}
  
  defp validate_cross_references(spec) do
    # This would validate references between different specs
    # For now, just return info about cross-references found
    cross_refs = extract_cross_references(spec)
    
    if length(cross_refs) > 0 do
      [%{type: :info, field: "cross_references", message: "Found #{length(cross_refs)} cross-references"}]
    else
      [%{type: :info, field: "cross_references", message: "No cross-references found"}]
    end
  end
  
  defp extract_cross_references(spec) do
    # Extract cross-dependencies from spec
    case Map.get(spec, "cross_dependencies") do
      nil -> []
      cross_deps when is_list(cross_deps) -> cross_deps
      _ -> []
    end
  end
end