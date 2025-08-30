#!/usr/bin/env elixir

# Load the converter module
Code.require_file("/Users/mikesimka/elias_garden_elixir/cli_utils/to_markdown/to_markdown.ex")

# Convert the full interview using our ELIAS converter
input_path = "/Users/mikesimka/elias_garden_elixir/learning_sandbox/raw_materials/jakob_uzkoreit_comp_history_interview.md.rtfd/TXT.rtf"
output_path = "/Users/mikesimka/elias_garden_elixir/learning_sandbox/notes/raw_ideas/jakob_uszkoreit_transformer_interview_FULL.md"

IO.puts("🔄 Converting full Jakob Uszkoreit interview using ELIAS Multi-Format Text Converter")
IO.puts("Input:  #{input_path}")
IO.puts("Output: #{output_path}")

case EliasUtils.MultiFormatTextConverter.convert(input_path, output_path, 
  extract_meta: true, 
  clean: true, 
  verbose: true,
  format: "rtf"
) do
  {:ok, message} ->
    IO.puts("✅ #{message}")
    
    # Show file size and line count
    case File.read(output_path) do
      {:ok, content} ->
        lines = String.split(content, "\n") |> length()
        chars = String.length(content)
        IO.puts("📊 Converted file stats:")
        IO.puts("   Lines: #{lines}")
        IO.puts("   Characters: #{chars}")
        IO.puts("   File: #{output_path}")
        
      {:error, reason} ->
        IO.puts("❌ Could not read output: #{reason}")
    end
    
  {:error, reason} ->
    IO.puts("❌ Conversion failed: #{reason}")
end