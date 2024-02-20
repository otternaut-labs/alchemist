defmodule Alchemist.Context do
  @moduledoc false
  defmacro __using__(_opts) do
    quote do
      import Ecto.Query, warn: false
      import Ecto.Changeset, only: [change: 2]

      @doc """
      Fetches all entries from the data store matching the given query.

      If soft delete is enabled, it will filter the result set based on
      whether or not the record has the column populated for the soft delete;
      and if so, omit it from the resultset.

      ## Example

          Context.all()
      """
      @spec all() :: list(@schema.t)
      def all() do
        # Execute the query with digesting the default criteria.
        query = from(s in @schema)

        # If this is a soft deleted schema, then we want to go ahead and apply
        # the filter automatically so dead data isnt returned.
        query = if soft_delete_enabled?(),
          do: where(query, [s], is_nil(field(s, ^Keyword.get(@schema_opts, :soft_delete)))),
        else: query

        @repository.all(query)
      end
      def all(_) do
        raise ArgumentError, message: "Invalid definition parameters passed to all!/0."
      end

      @doc """
      Fetches a single struct from the data store where the primary key matches the
      given id. If soft delete is enabled, it will ignore records that are soft deleted.

      ## Example

          Context.get(42)
      """
      @spec get(Number.t) :: Ecto.Schema.t | nil
      def get(id) when is_integer(id) or is_binary(id) do
        # Execute the query with digesting the default criteria.
        query = from(s in @schema) |> where([s], s.id == ^id)

        # If this is a soft deleted schema, then we want to go ahead and apply
        # the filter automatically so dead data isnt returned.
        query = if soft_delete_enabled?(),
          do: where(query, [s], is_nil(field(s, ^Keyword.get(@schema_opts, :soft_delete)))),
        else: query

        @repository.one(query)
      end
      def get(nil), do: nil
      def get(_) do
        raise ArgumentError, message: "Invalid definition parameters passed to get/1."
      end

      @doc """
      Similar to `c:get/1` but raises `Ecto.NoResultsError` if no record was found.

      ## Example

          Context.get!(42)
      """
      def get!(id) do
        case get(id) do
          nil -> raise Ecto.NoResultsError
          result -> result
        end
      end

      @doc """
      Depending on if an existing struct is passed, this method will encapsulate
      the update and insert methods to provide a single consolidated method.

      ## Example

        Context.save(existing_schema, attrs)

        Context.save(nil, attrs)
      """
      @spec save(Ecto.Schema.t | nil, Map.t) :: Ecto.Schema.t
      def save(_, attrs) when not is_map(attrs) do
        raise ArgumentError, message: "Invalid definition parameters passed to save!/2."
      end
      def save(nil, attrs) do
        with %Ecto.Changeset{valid?: true} = changeset <- @schema.changeset(%@schema{}, attrs),
             {:ok, created_schema} <- @repository.insert(changeset) do
          {:ok, created_schema}
        end
      end
      def save(%@schema{} = existing, attrs) do
        with %Ecto.Changeset{valid?: true} = changeset <- @schema.changeset(existing, attrs),
             {:ok, updated_schema} <- @repository.update(changeset) do
          {:ok, updated_schema}
        end
      end

      @doc """
      Similar to `c:save/2` but raises `Ecto.InvalidChangesetError` if the update
      or create mechanism fails.

      ## Example

          Context.save!(existing_schema, attrs)

          Context.save!(nil, attrs)
      """
      @spec save!(Ecto.Schema.t | nil, Map.t) :: Ecto.Schema.t
      def save!(schema, attrs) do
        case save(schema, attrs) do
          {:ok, schema} -> schema
          %Ecto.Changeset{valid?: false} -> raise Ecto.InvalidChangesetError
          {:error, _} -> raise Ecto.InvalidChangesetError
        end
      end

      @doc """
      Depending on whether or not this context is set in soft delete mode
      or not, it will issue either an update or delete appropriately to handle
      the delete mechanism.

      ## Example

          Context.delete(schema)
      """
      @spec delete(Ecto.Schema.t) :: Ecto.Schema.t
      def delete(%@schema{} = schema) do
        if soft_delete_enabled?(),
          do: @repository.update(change(schema, deleted_at: soft_delete_timestamp!(:now))),
        else: @repository.delete(schema)
      end
      def delete(_) do
        raise ArgumentError, message: "Invalid definition parameters passed to delete!/1."
      end

      @doc """
      Similar to `c:delete/1` but raises `Ecto.InvalidChangesetError` if the delete
      mechanism fails.

      ## Example

          Context.delete!(schema)
      """
      @spec delete!(Ecto.Schema.t) :: Ecto.Schema.t
      def delete!(schema) do
        case delete(schema) do
          {:ok, schema} -> schema
          {:error, _} -> raise Ecto.InvalidChangesetError
        end
      end

      defoverridable all: 0, get: 1, get!: 1, save: 2, save!: 2, delete: 1, delete!: 1

      # Soft Delete Helpers
      #
      # The following functions are methods that will allow us to handle
      # soft deletes internally in this context. This will make sure that
      # that when performing deletes, it will set the correct type of timestamp.

      @spec soft_delete_enabled? :: Boolean.t
      defp soft_delete_enabled? do
        not is_nil(Keyword.get(@schema_opts, :soft_delete, nil))
      end

      @spec soft_delete_timestamp!(Atom.t) :: NaiveDateTime.t | DateTime.t
      defp soft_delete_timestamp!(:now) do
        case @schema.__schema__(:type, Keyword.get(@schema_opts, :soft_delete)) do
          :naive_datetime ->
            DateTime.to_naive(DateTime.utc_now()) |> NaiveDateTime.truncate(:second)
          :utc_datetime ->
            DateTime.utc_now()
          # Cant detect field type, so we will raise an exception saying that
          # we are unable to determine the type.
          _ ->
            raise RuntimeError, message: "Failed to determine the field type to generate timestamps."
        end
      end
      defp soft_delete_timestamp!(_) do
        raise ArgumentError, message: "Invalid definition parameters passed to timestamp/1."
      end
    end
  end

  @doc """
  Defines the repository to use for all context actions.

  By default this module will inherit all functionality
  and options of the repository based on its initial setup.
  """
  @spec repo(Ecto.Repo.t) :: none
  defmacro repo(repo) do
    quote do
      Module.put_attribute(__MODULE__, :repository, unquote(repo))
    end
  end

  @doc """
  Defines the schema to use for all context actions.

  By default usage, any and all options set in the schema
  will be applied to actions in this module context.
  """
  @spec schema(Ecto.Schema.t, Keyword.t) :: none
  defmacro schema(schema, opts \\ []) do
    quote do
      Module.put_attribute(__MODULE__, :schema, unquote(schema))
      Module.put_attribute(__MODULE__, :schema_opts, unquote(opts))
    end
  end
end
