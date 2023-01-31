defmodule Wingman.Mattermost do
  use Agent

  @team "canonical"

  defstruct name: nil, client: nil

  def start_link(_) do
    header = [ {"authorization", "Bearer #{Application.get_env(:wingman, :mattermost)[:token]}" } ]
    middleware = [
      { Tesla.Middleware.BaseUrl, Application.get_env(:wingman, :mattermost)[:api_url] },
      { Tesla.Middleware.Headers, header },
      Tesla.Middleware.PathParams,
      Wingman.MapHttpResponse
    ]
    Agent.start_link(fn -> %Wingman.Mattermost{ client: Tesla.client(middleware) } end, name: __MODULE__)
  end

  def client() do
    Agent.get(__MODULE__, &(&1.client))
  end

  def me() do
    if name = Agent.get(__MODULE__, &(&1.name)) do
      name
    else
      { :ok, 200, %{ username: n } } = user()
      Agent.update(__MODULE__, &( %{ &1 | name: n } ))
      n
    end
  end

  def get(path, opts \\ []) do
    client()
    |> Tesla.get(path, opts)
  end

  def post(path, body, opts \\ [])
  def post(path, body, opts) when not is_binary(body) do
    post(path, Jason.encode!(body), opts)
  end
  def post(path, body, opts) do
    client()
    |> Tesla.post(path, body, opts)
  end

  def put(path, body, opts \\ []) do
    client()
    |> Tesla.put(path, body, opts)
  end

  def users do
    get("/users")
  end

  def user_stats do
    get("/users/stats")
  end

  def user(user \\ "me") do
    cond do
      String.starts_with?(user, "@") ->
        get("/users/username/:user", opts: [path_params: [user: String.trim_leading(user, "@")]])
      String.contains?(user, "@") ->
        get("/users/email/:email", opts: [path_params: [email: user]])
      user == "me" ->
        get("/users/me")
      byte_size(user) == 26 ->
        get("/users/:user_id", opts: [path_params: [user_id: user]])
      true ->
        get("/users/username/:user", opts: [path_params: [user: user]])
    end
  end

  def user_sessions(id \\ "me") do
    get("/users/:id/sessions", opts: [path_params: [id: id]])
  end

  def user_tokens(id \\ "me") do
    get("/users/:id/tokens", opts: [path_params: [id: id]])
  end

  def user_teams(id \\ "me") do
    get("/users/:id/teams", opts: [path_params: [id: id]])
  end

  def user_status(id \\ "me") do
    get("/users/:id/status", opts: [path_params: [id: id]])
  end

  def user_status_update(data) do
    put("/users/me/status", data)
  end

  def channels do
    get("/channels")
  end

  def teams do
    get("/teams")
  end

  def channel(chan) do
    get("/teams/name/#{@team}/channels/name/:name", opts: [path_params: [name: chan]])
  end

  def post_create(data) do
    post("/posts", data)
  end

end
