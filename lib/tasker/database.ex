defmodule Tasker.Database do
  alias Tasker.Database.Worker

  @db_folder "./data"
  @timeout :timer.seconds(5)

  def child_spec(_) do
    [node_name, _] = "#{node()}" |> String.split("@")
    folder = "#{@db_folder}/#{node_name}"
    File.mkdir_p!(folder)

    :poolboy.child_spec(
      __MODULE__,
      [
        name: {:local, __MODULE__},
        worker_module: Worker,
        size: 5
      ],
      [folder]
    )
  end

  def store(key, data) do
    {_, bad_nodes} =
      :rpc.multicall(
        __MODULE__,
        :store_local,
        [key, data],
        @timeout
      )

    Enum.each(bad_nodes, fn node ->
      IO.puts("Failed to store on node #{node}")
    end)

    :ok
  end

  def store_local(key, data) do
    :poolboy.transaction(__MODULE__, fn pid ->
      Worker.store(pid, key, data)
    end)
  end

  def get(key) do
    :poolboy.transaction(__MODULE__, fn pid ->
      Worker.get(pid, key)
    end)
  end
end
