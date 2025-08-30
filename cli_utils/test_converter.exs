#!/usr/bin/env elixir

# Load the converter module directly
Code.require_file("/Users/mikesimka/elias_garden_elixir/cli_utils/to_markdown/to_markdown.ex")

# Test conversion
input_path = "/Users/mikesimka/elias_garden_elixir/learning_sandbox/raw_materials/jakob_uzkoreit_comp_history_interview.md.rtfd"
output_path = "/Users/mikesimka/elias_garden_elixir/learning_sandbox/notes/raw_ideas/jakob_uszkoreit_transformer_interview.md"

IO.puts("🔄 Testing ELIAS To-Markdown Converter")
IO.puts("Input:  #{input_path}")
IO.puts("Output: #{output_path}")
IO.puts("")

# Check dependencies first
IO.puts("📋 Checking dependencies...")
system_info = EliasUtils.ToMarkdown.system_info()

IO.puts("Supported formats: #{Enum.join(system_info.supported_formats, ", ")}")

Enum.each(system_info.dependencies, fn {tool, available} ->
  status = if available, do: "✅", else: "❌"
  IO.puts("  #{status} #{tool}")
end)

IO.puts("")

if system_info.all_available do
  IO.puts("🎉 All dependencies available! Starting conversion...")
  IO.puts("")
  
  # Perform conversion with metadata extraction and cleaning
  case EliasUtils.ToMarkdown.convert(input_path, output_path, 
    extract_meta: true, 
    clean: true, 
    verbose: true
  ) do
    {:ok, message} ->
      IO.puts("✅ #{message}")
      IO.puts("")
      IO.puts("📄 Preview of converted content:")
      case File.read(output_path) do
        {:ok, content} ->
          preview = content
          |> String.split("\n")
          |> Enum.take(20)
          |> Enum.join("\n")
          
          IO.puts(preview)
          if String.length(content) > String.length(preview) do
            IO.puts("\n... (truncated for preview)")
          end
          
        {:error, reason} ->
          IO.puts("❌ Could not read output file: #{reason}")
      end
      
    {:error, reason} ->
      IO.puts("❌ Conversion failed: #{reason}")
  end
else
  IO.puts("⚠️ Some dependencies missing - conversion may fail")
end