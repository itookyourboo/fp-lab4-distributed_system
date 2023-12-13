defmodule Tasker.Mapper do
  def start_link do
    IO.puts("Starting mapper")

    DynamicSupervisor.start_link(
      name: __MODULE__,
      strategy: :one_for_one
    )
  end

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end

  def server_process(name) do
    existing_process(name) || new_process(name)
  end

  def existing_process(name) do
    Tasker.Server.whereis(name)
  end

  def new_process(name) do
    child = DynamicSupervisor.start_child(__MODULE__, {Tasker.Server, name})

    case child do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end
end
