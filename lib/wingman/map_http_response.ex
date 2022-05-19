defmodule Wingman.MapHttpResponse do
  @behaviour Tesla.Middleware

  def call(env, next, _) do
    env
    |> Tesla.run(next)
    |> decode()
  end

  defp decode({:ok, %{ status: status, body: body }}) do
    case { status, body } do
      { status, "" } ->
        { :ok, status, nil }
      { status, _ } when status in 200..299 ->
        { :ok, status, Jason.decode!(body, keys: :atoms) }
      { status, _ } ->
        { :error, status, Jason.decode!(body, keys: :atoms) }
    end
  end
  defp decode(error), do: error
end
