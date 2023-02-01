defmodule Wingman.Telegram do
  import Common.Util

  def request(method), do: request(method, [])
  def request(method, map) when is_map(map), do: request(method, Enum.into(map, []))
  def request(method, opts) when is_atom(method) do
    method
    |> to_string
    |> String.split("_", parts: 2)
    |> List.update_at(1, &Macro.camelize/1)
    |> Enum.join()
    |> request(opts)
  end
  def request(method, opts) do
    {token, _chat_id} = Application.get_env(:wingman, :telegram)
    {status, res} = Telegram.Api.request(token, method, opts)
    {status, keys_to_atoms(res)}
  end

end
