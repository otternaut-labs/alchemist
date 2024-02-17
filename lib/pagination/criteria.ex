defmodule Alchemist.Pagination.Criteria do
  @moduledoc false
  @derive Jason.Encoder
  defstruct __meta__: [],
            __request__: %{},
            page: 1,
            size: 25,
            query: nil,
            sort_by: nil

  @typedoc "Define the allow pagination fields and their associated types."
  @type t() :: %__MODULE__{
    __meta__: Keyword.t, # Pagination settings from inheriting module.
    __request__: Map.t,  # The raw request data.
    page: Integer.t,     # Controls Offset
    size: Integer.t,     # Controls Limit
    query: String.t,     # For Searching Results
    sort_by: String.t,   # For Sorting Results
  }

  @doc """
  Convert request parameters send by web requests to the proper structure
  for making pagination requests. This will also help keep data consistent
  so that we dont try to filter or query from bad situations.

  ## Examples
  iex> new(params, [])
  Criteria.t
  """
  @spec new(Map.t, Keyword.t) :: __MODULE__.t
  def new(attrs, opts \\ []) do
    %__MODULE__{
      __meta__: opts,
      __request__: attrs,
      page: String.to_integer(attrs["page"] || "1"),
      size: parse_size(attrs["size"], Keyword.get(opts, :size, [])),
      query: attrs["q"] || nil,
      sort_by: parse_sort_by(attrs["sort_by"], Keyword.get(opts, :sort, []))
    }
  end

  # Resultset Size Parsing
  #
  # Format and return the correct size for the resultset so that
  # we can make sure that people do not abuse the API inheriting
  # this functionality.
  defp parse_size(nil, opts), do: opts[:default]
  defp parse_size(size, opts) do
    cond do
      # If the size requested is larger than max, reduce.
      String.to_integer(size) > opts[:max] -> opts[:max]
      # Fallthrough.
      true -> String.to_integer(size)
    end
  end

  # Resultset Sort Parsing
  #
  # Format and return the sort_by column filter. This will allow
  # us to order the returned resultset.
  defp parse_sort_by(sort, opts) do
    cond do
      # If the sort is nil, and theres no default, return nil.
      is_nil(sort) and is_nil(opts[:default]) -> nil
      # If the sort is nil, but there is a default, return that.
      is_nil(sort) and not is_nil(opts[:default]) -> Atom.to_string(opts[:default])
      # If the sort column specified is not in the allowed columns
      # well return a nil so that no sorting is applied.
      not is_nil(sort) and String.to_atom(String.replace(sort, "-", "")) not in opts[:on] -> nil
      # Fallthrough.
      true -> sort
    end
  end
end
