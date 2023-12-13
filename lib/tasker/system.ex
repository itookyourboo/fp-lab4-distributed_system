defmodule Tasker.System do
  def start_link do
    Supervisor.start_link(
      [
        Tasker.Database,
        Tasker.Mapper,
        Tasker.API
      ],
      strategy: :one_for_one
    )
  end
end
