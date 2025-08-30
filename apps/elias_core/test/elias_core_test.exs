defmodule EliasCoreTest do
  use ExUnit.Case
  doctest EliasCore

  test "greets the world" do
    assert EliasCore.hello() == :world
  end
end
