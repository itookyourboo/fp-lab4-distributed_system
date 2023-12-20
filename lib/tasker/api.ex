defmodule Tasker.API do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  def child_spec(_) do
    Plug.Cowboy.child_spec(
      scheme: :http,
      options: [port: Application.fetch_env!(:tasker, :port)],
      plug: __MODULE__
    )
  end

  get "/entries" do
    conn = Plug.Conn.fetch_query_params(conn)
    name = Map.fetch!(conn.params, "list")

    entries =
      name
      |> Tasker.Mapper.server_process()
      |> Tasker.Server.entries()
      |> format_entries

    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(200, entries)
  end

  defp format_entries(entries) do
    entries
    |> Enum.map(fn entry ->
      IO.inspect(entry)
      "#{entry.id}. #{entry.title}"
    end)
    |> Enum.join("\n")
  end

  post "/entries" do
    conn = Plug.Conn.fetch_query_params(conn)
    name = Map.fetch!(conn.params, "list")
    title = Map.fetch!(conn.params, "title")

    name
    |> Tasker.Mapper.server_process()
    |> Tasker.Server.add_entry(%{title: title})

    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(200, "OK")
  end

  match _ do
    Plug.Conn.send_resp(conn, 404, "Not found")
  end
end
