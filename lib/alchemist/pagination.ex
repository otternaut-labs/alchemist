defmodule Alchemist.Pagination do
  @moduledoc false
  defmacro __using__(_opts) do
    quote do
      import Ecto.Query, warn: false
      alias Alchemist.Pagination.{Page, Criteria, QueryBuilder}

      @doc """
      Depending on the passed parameters, we want to go ahead and return a list of
      all schemas related to this query. The parameters can include things like page
      number, filters, search criteria, etc.

      ## Examples
      iex> paginate(criteria)
      [%Schema{}...]
      """
      @spec paginate!(Map.t | Criteria.t) :: Page.t
      def paginate!(%Criteria{} = criteria) do
        # Execute the query with digesting the default criteria.
        query = from(s in @schema)

        # If this is a soft deleted schema, then we want to go ahead and apply
        # the filter automatically so dead data isnt returned.
        query = if soft_delete_enabled?(),
          do: where(query, [s], is_nil(field(s, ^Keyword.get(@schema_opts, :soft_delete)))),
        else: query

        # Apply filters, sorting, etc.
        query =
          query
          |> QueryBuilder.query(criteria.query, Keyword.get(__pagination__(:query), :on, []))
          |> QueryBuilder.range(Map.take(
               criteria.__request__,
               Enum.map(Keyword.get(__pagination__(:range), :on, []), &Atom.to_string/1)
             ))
          |> QueryBuilder.where(Map.take(
               criteria.__request__,
               Enum.map(Keyword.get(__pagination__(:filter), :on, []), &Atom.to_string/1)
             ))

        # Setup the paginated query with limit and offset.
        paginated_query =
          query
          |> QueryBuilder.limit(criteria.size)
          |> QueryBuilder.offset((criteria.page - 1) * criteria.size)
          |> QueryBuilder.order_by(criteria.sort_by)

        %Page{
          _links: %{
            prev: nil,
            self: nil,
            next: nil,
          },
          total: @repository.aggregate(query, :count),
          results: @repository.all(paginated_query)
        }
      end
      def paginate!(attrs) when is_map(attrs) do
        paginate!(criteria!(attrs))
      end
      def paginate!(_) do
        raise ArgumentError, message: "Invalid definition parameters passed to paginate/1."
      end

      @doc """
      This method wraps the internal criteria module that will allow us to
      build customized queries for specific results. If attrs is empty, we
      just return the defaults.

      ## Examples
      iex> criteria(attrs)
      Criteria.t
      """
      @spec criteria!(Map.t) :: Criteria.t
      def criteria!(attrs) when is_map(attrs) do
        Criteria.new(attrs, __pagination__())
      end
      def criteria!(_) do
        raise ArgumentError, message: "Invalid definition parameters passed to criteria/1."
      end

      @doc """
      Returns the current pagination setup for this module.

      ## Examples
      iex> __MODULE__.__pagination
      [..]
      """
      @spec __pagination__() :: Keyword.t
      def __pagination__(), do: @__pagination__

      @doc """
      Return the current pagination option from the internal module
      attribute registration. This will act as a helper for other functionality.

      ## Examples
      iex> __MODULE__.__pagination__(:size)
      [..]
      """
      @spec __pagination__(Atom.t) :: Keyword.t
      def __pagination__(opt) when opt in [:size, :sort, :filter, :query, :range] do
        Keyword.get(@__pagination__, opt, nil)
      end
      def __pagination__(_), do: nil
    end
  end

  @doc """
  This wrapper is a macro for instantiation of this recipe. This will
  allow us to configure and setup individual pagination settings with added
  syntactic sugar and methods.

  ## Usage
  pagination do
    size default: 24, max: 100
    sort :inserted_at, on: []
    filter on: []
    query on: []
    range on: []
  end
  """
  @spec pagination(any()) :: none()
  defmacro pagination(do: block) do
    exposed = quote do
      try do
        # Register some default attributes to be used for pagination
        # purposes. This will allow us to set minimums, etc.
        Module.put_attribute(__MODULE__, :__pagination__, [
          size: [default: 20, max: 100],
          sort: [default: nil, on: []],
          filter: [on: []],
          query: [on: []],
          range: [on: []]
        ])

        # Import the relevant setup macros that represent all of
        # the various recipe actions that can be applied.
        import Alchemist.Pagination,
          only: [size: 1, sort: 1, filter: 1, query: 1, range: 1]

        # By unquoting the passed block, it will run the macros
        # underneath and allow us to evaluate the result. This will mean
        # we can perform validation on the resulting block.
        unquote(block)

        # Pull in the supporting functions through the wrapper for
        # alchemist. This will allow basic repo functions and more.
        use Alchemist.Pagination
      after
        :ok
      end
    end

    quote do
      unquote(exposed)
    end
  end

  @doc """
  This macro will allow us to setup the various settings for limits
  on result sets (min, default, max, etc).

  ## Options
  default: Number.t - the number of results to send back by default.
  max: Number.t - the maximum number of results allows in the size query.

  ## Usage
  size default: 24, max: 100
  """
  @spec size(Keyword.t) :: none
  defmacro size(opts \\ []) do
    quote do
      Module.put_attribute(__MODULE__, :__pagination__, Keyword.merge(
        Module.get_attribute(__MODULE__, :__pagination__), [
          size: [
            # Sets the default resultset size.
            default: Keyword.get(unquote(opts), :default, 20),
            # Sets the maximum resultset size.
            max: Keyword.get(unquote(opts), :max, 100)
          ]
      ]))
    end
  end

  @doc """
  This macro will allow us to setup the various sorting abilities
  for the pagination implementation. This includes which columns to
  allow sorting on, and the default sort & direction.

  ## Options
  default: Atom.t - the default field and direction to sort on.
  on: list(Atom.t) - a list of columns that are allowed for sorting.

  ## Usage
  sort on: [:my_column], default: :my_column
  """
  @spec sort(Keyword.t) :: none
  defmacro sort(opts \\ []) do
    quote do
      Module.put_attribute(__MODULE__, :__pagination__, Keyword.merge(
        Module.get_attribute(__MODULE__, :__pagination__), [
          sort: [
            # Sets the default sort column and direction
            default: Keyword.get(unquote(opts), :default, nil),
            # Sets the columns allowed for sorting.
            on: Keyword.get(unquote(opts), :on, [])
          ]
      ]))
    end
  end

  @doc """
  This macro will allow us to setup the various filtering abilities
  for the pagination implementation. This includes which columns to
  allow filtering on, etc.

  ## Options
  on: list(Atom.t) - a list of columns that are allowed for filtering.

  ## Usage
  filter on: [:my_column]
  """
  @spec filter(Keyword.t) :: none
  defmacro filter(opts \\ []) do
    quote do
      Module.put_attribute(__MODULE__, :__pagination__, Keyword.merge(
        Module.get_attribute(__MODULE__, :__pagination__), [
          filter: [
            # Sets the columns allowed for filtering data on.
            on: Keyword.get(unquote(opts), :on, [])
          ]
      ]))
    end
  end

  @doc """
  This macro will allow us to setup the various querying abilities
  for the pagination implementation. This includes which columns to
  allow querying on, type of query, etc.

  ## Options
  on: list(Atom.t) - a list of columns that are allowed for querying.

  ## Usage
  query on: [:my_column]
  """
  @spec query(Keyword.t) :: none
  defmacro query(opts \\ []) do
    quote do
      Module.put_attribute(__MODULE__, :__pagination__, Keyword.merge(
        Module.get_attribute(__MODULE__, :__pagination__), [
          query: [
            # Sets the columns allowed for full text search.
            on: Keyword.get(unquote(opts), :on, [])
          ]
      ]))
    end
  end

  @doc """
  This macro will allow us to setup the various range abilities
  for the pagination implementation. This will allow users to set
  ranges for result set (i.e. inserted_at between).

  ## Options
  on: list(Atom.t) - a list of columns that are allowed for ranges.

  ## Usage
  range on: [:my_column]
  """
  @spec range(Keyword.t) :: none
  defmacro range(opts \\ []) do
    quote do
      Module.put_attribute(__MODULE__, :__pagination__, Keyword.merge(
        Module.get_attribute(__MODULE__, :__pagination__), [
          range: [
            # Sets the columns allowed for ranges of results.
            on: Keyword.get(unquote(opts), :on, [])
          ]
      ]))
    end
  end
end
