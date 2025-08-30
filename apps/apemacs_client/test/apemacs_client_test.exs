defmodule ApemacsClientTest do
  use ExUnit.Case
  doctest ApemacsClient

  test "greets the world" do
    assert ApemacsClient.hello() == :world
  end
end
