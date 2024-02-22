defmodule Alchemist.Query do
  @moduledoc false
  import Ecto.Query, warn: false

  @doc """
  Apply a date range filter based on the passed starting and ending dates
  as well as the column specified. If neither are passed, just throw back
  the range filter.

  ## Examples
  iex> range(query, column, starting, ending)
  Ecto.Query.t
  """
  def range(query, ranges) when is_map(ranges) and map_size(ranges) < 1, do: query
  def range(query, ranges) do
    Enum.reduce(ranges, query, fn {column, range}, acc ->
      column = if is_atom(column), do: column, else: String.to_atom(column)

      acc = if not is_nil(range["after"]),
        do: Ecto.Query.where(acc, [q], field(q, ^column) >= ^range["after"]),
      else: acc

      acc = if not is_nil(range["before"]),
        do: Ecto.Query.where(acc, [q], field(q, ^column) <= ^range["before"]),
      else: acc

      acc
    end)
  end

  @doc """
  Apply a limit to the query through the passed query and parameter.

  ## Examples
  iex> limit(query, 0)
  Ecto.Query.t
  """
  @spec limit(Ecto.Query.t, Number.t) :: Ecto.Query.t
  def limit(query, limit) when is_nil(limit), do: query
  def limit(query, limit) when limit < 1, do: query
  def limit(query, limit), do: query |> Ecto.Query.limit(^limit)

  @doc """
  Apply an offset to the query through the passed query and parameter.

  ## Examples
  iex> offset(query, 0)
  Ecto.Query.t
  """
  @spec offset(Ecto.Query.t, Number.t) :: Ecto.Query.t
  def offset(query, offset) when is_nil(offset), do: query
  def offset(query, offset) when offset < 1, do: query
  def offset(query, offset), do: query |> Ecto.Query.offset(^offset)

  @doc """
  Apply the query fields for the various fields that are passed into the
  methods (list of atoms). This will allow us to mimic a full text search but
  keep it optimized for performance.

  TODO:
  Convert this feature to use full text search when applicable so that we can
  optimize the performance.
  See https://nathanmlong.com/2018/01/fast-fulltext-search-with-ecto-and-postgresql for example.

  ## Example
  iex> query(query, "foobar", [:name, :description])
  Ecto.Query.t
  """
  @spec query(Ecto.Query.t, String.t, List.t) :: Ecto.Query.t
  def query(query, term, _fields) when is_nil(term), do: query
  def query(query, _term, fields) when length(fields) < 1, do: query
  def query(query, term, fields) do
    Enum.reduce(fields, query, fn field, acc ->
      column = if is_atom(field), do: field, else: String.to_atom(field)
      acc |> Ecto.Query.where([q], ilike(field(q, ^column), ^"%#{term}%"))
    end)
  end

  @doc """
  Apply the filters for the various fields map passed in the request. The
  filters might either be singular or a list, and well apply them difference. Direct
  comparisons will be a "=" query, and a group would be an "in" query.

  ## Example
  iex> where(query, %{}, [])
  Ecto.Query.t
  """
  @spec where(Ecto.Query.t, Map.t) :: Ecto.Query.t
  def where(query, filters) when is_map(filters) and map_size(filters) < 1, do: query
  def where(query, filters) when is_list(filters) and length(filters) < 1, do: query
  def where(query, filters) do
    Enum.reduce(filters, query, fn {field, criteria}, acc ->
      column = if is_atom(field), do: field, else: String.to_atom(field)
      if is_list(criteria),
        do: acc |> Ecto.Query.where([q], field(q, ^column) in ^criteria),
      else: acc |> Ecto.Query.where([q], field(q, ^column) == ^criteria)
    end)
  end

  @doc """
  Apply correct sorting parameter based on the passed term and query.

  ## Example
  iex> order_by(query, "-inserted_at")
  Ecto.Query.t
  """
  @spec order_by(Ecto.Query.t, String.t) :: Ecto.Query.t
  def order_by(query, term) when is_nil(term), do: query
  def order_by(query, term) do
    column = String.replace_prefix(term, "-", "") |> String.to_atom()
    if String.at(term, 0) == "-",
      do: query |> Ecto.Query.order_by(desc: ^column),
      else: query |> Ecto.Query.order_by(asc: ^column)
  end
end
