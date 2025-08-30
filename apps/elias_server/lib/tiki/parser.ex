defmodule Tiki.Parser do
  @moduledoc """
  Tiki Specification Parser - Core YAML parsing and validation
  
  Per Architect guidance: Core library for parsing .tiki files with
  hierarchical tree structure validation, dependency extraction,
  and code reference mapping.
  
  Designed as a stateless library that integrates with UFM coordination
  and individual manager validation workflows.
  """
  
  require Logger
  
  @spec_dir Path.join([File.cwd!(), "apps", "elias_server", "priv", "manager_specs"])
  
  # Public API
  
  @doc """
  Parse a .tiki specification file into structured data.
  
  Returns parsed specification with metadata, validation status,
  and hierarchical component tree ready for testing and validation.
  """
  def parse_spec_file(spec_file) when is_binary(spec_file) do
    spec_path = resolve_spec_path(spec_file)
    
    with {:ok, content} <- File.read(spec_path),
         {:ok, parsed_yaml} <- parse_yaml_content(content),
         {:ok, validated_spec} <- validate_spec_structure(parsed_yaml, spec_file) do
      
      # Add processing metadata
      final_spec = Map.put(validated_spec, "_tiki_metadata", %{
        file: spec_file,
        path: spec_path,
        parsed_at: DateTime.utc_now(),
        checksum: calculate_checksum(content),
        version: Map.get(parsed_yaml, "version", "unknown")
      })
      
      {:ok, final_spec}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Extract hierarchical component tree from parsed specification.
  
  Returns tree structure suitable for breadth-first/depth-first traversal
  as specified in Architect's testing methodology.
  """
  def extract_component_tree(spec) when is_map(spec) do
    root_component = %{
      id: Map.get(spec, "id", "root"),
      name: Map.get(spec, "name", "unknown"),
      level: 0,
      parent_id: nil,
      children: [],
      metadata: Map.get(spec, "metadata", %{}),
      code_ref: Map.get(spec, "code_ref"),
      module: Map.get(spec, "module")
    }
    
    case Map.get(spec, "children") do
      nil -> 
        {:ok, root_component}
        
      children when is_list(children) ->
        case build_tree_structure(children, root_component.id, 1) do
          {:ok, child_components} ->
            final_root = %{root_component | children: child_components}
            {:ok, final_root}
            
          {:error, reason} ->
            {:error, reason}
        end
        
      _ ->
        {:error, "Invalid children structure in specification"}
    end
  end
  
  @doc """
  Extract all dependencies from specification for System Harmonizer analysis.
  
  Returns comprehensive dependency mapping including direct dependencies,
  cross-references, and internal component dependencies.
  """
  def extract_dependencies(spec) when is_map(spec) do
    # Direct dependencies from metadata
    direct_deps = get_in(spec, ["metadata", "dependencies"]) || []
    
    # Cross-references from cross_dependencies section
    cross_refs = case Map.get(spec, "cross_dependencies") do
      nil -> []
      cross_deps when is_list(cross_deps) ->
        Enum.map(cross_deps, fn ref ->
          %{
            source: Map.get(ref, "source"),
            target: Map.get(ref, "target"),
            type: Map.get(ref, "type", "unknown")
          }
        end)
      _ -> []
    end
    
    # Extract internal component dependencies recursively
    internal_deps = extract_internal_dependencies(spec)
    
    %{
      direct_dependencies: direct_deps,
      cross_references: cross_refs,
      internal_dependencies: internal_deps,
      total_dependency_count: length(direct_deps) + length(cross_refs) + length(internal_deps)
    }
  end
  
  @doc """
  Extract code references for validation against actual implementation.
  
  Returns all code_ref entries for validation by Tiki.Validator.
  """
  def extract_code_references(spec) when is_map(spec) do
    extract_code_refs_recursive(spec, [])
  end
  
  @doc """
  Extract performance expectations for regression testing.
  
  Returns performance thresholds and expectations used by System Harmonizer
  for approval decisions and regression detection.
  """
  def extract_performance_expectations(spec) when is_map(spec) do
    # Root level performance expectations
    root_perf = get_in(spec, ["metadata", "performance"]) || %{}
    
    # Component-level performance expectations from children
    child_perf = extract_child_performance(spec)
    
    # Testing configuration performance expectations
    test_perf = case Map.get(spec, "testing") do
      nil -> %{}
      testing_config ->
        Map.get(testing_config, "performance_benchmarks", [])
        |> Enum.map(fn benchmark ->
          {Map.get(benchmark, "id"), Map.drop(benchmark, ["id"])}
        end)
        |> Map.new()
    end
    
    %{
      root_performance: root_perf,
      component_performance: child_perf,
      test_benchmarks: test_perf,
      harmonizer_rules: Map.get(spec, "harmonizer_rules", %{})
    }
  end
  
  @doc """
  Get list of all available .tiki specification files.
  """
  def list_available_specs do
    case File.ls(@spec_dir) do
      {:ok, files} ->
        tiki_files = files
        |> Enum.filter(&String.ends_with?(&1, ".tiki"))
        |> Enum.map(&Path.rootname/1)
        
        {:ok, tiki_files}
        
      {:error, reason} ->
        {:error, "Cannot read spec directory: #{reason}"}
    end
  end
  
  # Private Functions
  
  defp resolve_spec_path(spec_file) do
    if Path.extname(spec_file) == ".tiki" do
      Path.join(@spec_dir, spec_file)
    else
      Path.join(@spec_dir, spec_file <> ".tiki")
    end
  end
  
  defp parse_yaml_content(content) do
    case YamlElixir.read_from_string(content) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, reason} -> {:error, "YAML parsing failed: #{inspect(reason)}"}
    end
  end
  
  defp validate_spec_structure(parsed_yaml, spec_file) do
    # Basic structure validation
    required_fields = ["id", "name", "version"]
    
    missing_fields = Enum.filter(required_fields, fn field ->
      not Map.has_key?(parsed_yaml, field)
    end)
    
    if length(missing_fields) > 0 do
      {:error, "Missing required fields in #{spec_file}: #{inspect(missing_fields)}"}
    else
      {:ok, parsed_yaml}
    end
  end
  
  defp build_tree_structure(children, parent_id, level) do
    try do
      components = Enum.map(children, fn child ->
        case child do
          child_map when is_map(child_map) ->
            component = %{
              id: Map.get(child_map, "id", "unknown"),
              name: Map.get(child_map, "name", "unknown"),
              level: level,
              parent_id: parent_id,
              children: [],
              metadata: Map.get(child_map, "metadata", %{}),
              code_ref: Map.get(child_map, "code_ref"),
              module: Map.get(child_map, "module"),
              functions: Map.get(child_map, "functions", [])
            }
            
            # Recursively build nested children
            case Map.get(child_map, "children") do
              nil ->
                component
                
              nested_children when is_list(nested_children) ->
                case build_tree_structure(nested_children, component.id, level + 1) do
                  {:ok, nested_components} ->
                    %{component | children: nested_components}
                  {:error, _reason} ->
                    component  # Continue with empty children on error
                end
                
              _ ->
                component
            end
            
          _ ->
            %{
              id: "invalid_child_#{level}",
              name: "invalid",
              level: level,
              parent_id: parent_id,
              children: [],
              metadata: %{},
              error: "Invalid child structure"
            }
        end
      end)
      
      {:ok, components}
      
    rescue
      error -> {:error, "Error building tree structure: #{inspect(error)}"}
    end
  end
  
  defp extract_internal_dependencies(spec) do
    # Extract dependencies between internal components
    case Map.get(spec, "children") do
      nil -> []
      children when is_list(children) ->
        extract_child_dependencies(children)
      _ -> []
    end
  end
  
  defp extract_child_dependencies(children) do
    Enum.flat_map(children, fn child ->
      child_deps = get_in(child, ["metadata", "dependencies"]) || []
      child_id = Map.get(child, "id", "unknown")
      
      # Create dependency relationships
      dependency_entries = Enum.map(child_deps, fn dep ->
        %{
          from: child_id,
          to: dep,
          type: :internal_dependency
        }
      end)
      
      # Recursively extract from nested children
      nested_deps = case Map.get(child, "children") do
        nil -> []
        nested_children when is_list(nested_children) ->
          extract_child_dependencies(nested_children)
        _ -> []
      end
      
      dependency_entries ++ nested_deps
    end)
  end
  
  defp extract_code_refs_recursive(spec, acc) do
    # Extract code_ref from current level
    updated_acc = case Map.get(spec, "code_ref") do
      nil -> acc
      code_ref -> [code_ref | acc]
    end
    
    # Recursively extract from children
    case Map.get(spec, "children") do
      nil ->
        updated_acc
      children when is_list(children) ->
        Enum.reduce(children, updated_acc, fn child, acc_inner ->
          extract_code_refs_recursive(child, acc_inner)
        end)
      _ ->
        updated_acc
    end
  end
  
  defp extract_child_performance(spec) do
    case Map.get(spec, "children") do
      nil -> %{}
      children when is_list(children) ->
        extract_performance_from_children(children)
      _ -> %{}
    end
  end
  
  defp extract_performance_from_children(children) do
    Enum.reduce(children, %{}, fn child, acc ->
      child_id = Map.get(child, "id", "unknown")
      child_perf = get_in(child, ["metadata", "performance"]) || %{}
      
      updated_acc = if map_size(child_perf) > 0 do
        Map.put(acc, child_id, child_perf)
      else
        acc
      end
      
      # Recursively extract from nested children
      case Map.get(child, "children") do
        nil -> updated_acc
        nested_children when is_list(nested_children) ->
          nested_perf = extract_performance_from_children(nested_children)
          Map.merge(updated_acc, nested_perf)
        _ -> updated_acc
      end
    end)
  end
  
  defp calculate_checksum(content) do
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end
end