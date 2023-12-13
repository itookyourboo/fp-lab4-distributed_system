defmodule Tasker.List do
  defstruct id: 1, entries: %{}

  def new(entries \\ []) do
    entries
    |> Enum.reduce(%__MODULE__{}, fn entry, list ->
      add_entry(list, entry)
    end)
  end

  def add_entry(list, entry) do
    entry = Map.put(entry, :id, list.id)
    new_entries = Map.put(list.entries, list.id, entry)

    %__MODULE__{list | entries: new_entries, id: list.id + 1}
  end

  def entries(list) do
    Map.values(list.entries)
  end

  def update_entry(list, new_entry) do
    update_entry(list, new_entry.id, fn -> new_entry end)
  end

  def update_entry(list, id, updater) do
    case Map.fetch(list.entries, id) do
      :error ->
        list

      {:ok, old_entry} ->
        new_entry = updater.(old_entry)
        new_entries = Map.put(list.entries, new_entry.id, new_entry)

        %__MODULE__{list | entries: new_entries}
    end
  end

  def delete_entry(list, id) do
    new_entries = Map.delete(list.entries, id)

    %__MODULE__{list | entries: new_entries}
  end

  def size(list) do
    map_size(list.entries)
  end
end
