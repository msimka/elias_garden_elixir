ExUnit.start()

# Test helper for ELIAS integration tests
# Provides common utilities for testing across the system

defmodule TestHelper do
  @moduledoc """
  Common test utilities for ELIAS system testing
  """
  
  def tmp_file_path(filename) do
    Path.join("/tmp", filename)
  end
  
  def fixture_file_path(filename) do
    Path.join("apps/elias_server/test/fixtures/converter_test_files", filename)
  end
  
  def cleanup_tmp_files(pattern \\ "*test*") do
    Path.wildcard(Path.join("/tmp", pattern))
    |> Enum.each(&File.rm/1)
  end
end