defmodule Wingman.Util do
  def trim_get(var), do: trim_get(var, :string)

  def trim_get(var, :string) do
    with str when is_binary(str) <- System.get_env(var),
         res when byte_size(res) > 0 <- String.trim(str)
    do
      res
    else
      _ -> nil
    end
  end

  def trim_get(var, :integer) do
    with str when is_binary(str) <- trim_get(var),
         {int, _} <- Integer.parse(str)
    do
      int
    else
      _ -> nil
    end
  end
end
