defmodule EliasClientTest do
  use ExUnit.Case
  doctest EliasClient

  test "greets the world" do
    assert EliasClient.hello() == :world
  end
end
