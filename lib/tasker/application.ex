defmodule Tasker.Application do
  use Application

  def start(_, _) do
    Tasker.System.start_link()
  end
end
