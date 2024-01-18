defmodule Tasker.Server do
  @idle_timeout :timer.seconds(10)

  use GenServer, restart: :temporary

  def start_link(name) do
    GenServer.start_link(
      Tasker.Server,
      name,
      name: global_name(name)
    )
  end

  def whereis(name) do
    case :global.whereis_name({__MODULE__, name}) do
      :undefined -> nil
      pid -> pid
    end
  end

  def add_entry(server, new_entry) do
    GenServer.call(server, {:add_entry, new_entry})
  end

  def entries(server) do
    GenServer.call(server, {:entries})
  end

  defp global_name(name) do
    {:global, {__MODULE__, name}}
  end

  @impl GenServer
  def init(name) do
    IO.puts("Starting server for #{name}")
    list = Tasker.Database.get(name) || Tasker.List.new()
    {:ok, {name, list}, @idle_timeout}
  end

  @impl GenServer
  def handle_call({:add_entry, new_entry}, _, {name, list}) do
    new_list = Tasker.List.add_entry(list, new_entry)
    {status, message} = Tasker.Database.store(name, new_list)
    {:reply, {status, message}, {name, new_list}, @idle_timeout}
  end

  def handle_call({:entries}, _, {name, list}) do
    {:reply, Tasker.List.entries(list), {name, list}, @idle_timeout}
  end

  @impl GenServer
  def handle_info(:timeout, {name, list}) do
    IO.puts("Stopping server for #{name}")
    {:stop, :normal, {name, list}}
  end
end
