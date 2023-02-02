defmodule Common.Util do
  def env_get(var), do: env_get(var, :string)

  def env_get(var, :string) do
    with str when is_binary(str) <- System.get_env(var),
         res when byte_size(res) > 0 <- String.trim(str)
    do
      res
    else
      _ -> nil
    end
  end

  def env_get(var, :integer) do
    with str when is_binary(str) <- env_get(var),
         {int, _} <- Integer.parse(str)
    do
      int
    else
      _ -> nil
    end
  end

  def env_get(var, :list) do
    var
    |> System.get_env(var)
    |> String.split(",")
    |> Enum.reject(&(byte_size(&1)==0))
  end

  def keys_to_atoms(json), do: keys_to_atoms(json, false)
  def keys_to_atoms(json, safe) when is_map(json) do
    Map.new(json, &(_reduce_keys_to_atoms(&1, safe)))
  end
  def keys_to_atoms(list, safe) when is_list(list), do: Enum.map(list, &keys_to_atoms(&1, safe))
  def keys_to_atoms(val, _safe), do: val

  defp _reduce_keys_to_atoms({key, val}, safe) when is_map(val) do
    case safe do
      true -> {String.to_existing_atom(key), keys_to_atoms(val, safe)}
      _ -> {String.to_atom(key), keys_to_atoms(val, safe)}
    end
  end
  defp _reduce_keys_to_atoms({key, val}, safe) when is_list(val) do
    case safe do
      true -> {String.to_existing_atom(key), Enum.map(val, &keys_to_atoms(&1, safe))}
      _ -> {String.to_atom(key), Enum.map(val, &keys_to_atoms(&1, safe))}
    end
  end
  defp _reduce_keys_to_atoms({key, val}, safe) do
    case safe do
      true -> {String.to_existing_atom(key), val}
      _ -> {String.to_atom(key), val}
    end
  end
end
