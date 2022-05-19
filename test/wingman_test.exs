defmodule WingmanTest do
  use ExUnit.Case
  doctest Wingman

  test "greets the world" do
    assert Wingman.hello() == :world
  end
end
