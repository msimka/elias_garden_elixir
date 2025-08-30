defmodule EliasServerTest do
  use ExUnit.Case
  doctest EliasServer

  test "greets the world" do
    assert EliasServer.hello() == :world
  end
end
