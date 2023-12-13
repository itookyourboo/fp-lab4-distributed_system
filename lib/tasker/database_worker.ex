defmodule Tasker.Database.Worker do
  use GenServer

  def start_link(folder) do
    GenServer.start_link(__MODULE__, folder)
  end

  def store(pid, key, data) do
    GenServer.call(pid, {:store, key, data})
  end

  def get(pid, key) do
    GenServer.call(pid, {:get, key})
  end

  @impl GenServer
  def init(folder) do
    {:ok, folder}
  end

  @impl GenServer
  def handle_call({:store, key, data}, _, folder) do
    folder
    |> file_name(key)
    |> file_write(data)

    {:reply, :ok, folder}
  end

  def handle_call({:get, key}, _, folder) do
    data =
      case file_read(file_name(folder, key)) do
        {:ok, content} -> :erlang.binary_to_term(content)
        _ -> nil
      end

    {:reply, data, folder}
  end

  defp file_read(filename) do
    File.read(filename)
  end

  defp file_write(filename, data) do
    File.write!(filename, :erlang.term_to_binary(data))
  end

  defp file_name(folder, key) do
    Path.join(folder, to_string(key))
  end
end
