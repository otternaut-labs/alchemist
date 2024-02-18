defmodule Alchemist.Pagination.Page do
  @moduledoc false
  @derive Jason.Encoder
  defstruct _links: %{},
            total: 0,
            results: []

  @typedoc "Define the page type for results."
  @type t() :: %__MODULE__{
    _links: Map.t(),     # Self referencing links for discovery.
    total: Integer.t(),  # The total number of results available.
    results: list(any()) # The resultset.
  }
end
