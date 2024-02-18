defmodule Alchemist.Recipe.Context do
  @moduledoc false
  defmacro __using__(_opts) do
    quote do
      import Ecto.Query, warn: false
      import Ecto.Changeset, only: [change: 2]

      @doc """
      Return all records in the database for the inheriting context. This will
      also apply soft delete logic to make sure nothing is bunk.

      ## Examples
      iex> all()
      [%Schema{}...]
      """
      @spec all!() :: list(@schema.t)
      def all!() do
        # Execute the query with digesting the default criteria.
        query = from(s in @schema)

        # If this is a soft deleted schema, then we want to go ahead and apply
        # the filter automatically so dead data isnt returned.
        query = if soft_delete_enabled?(),
          do: where(query, [s], is_nil(field(s, ^Keyword.get(@schema_opts, :soft_delete)))),
        else: query

        @repository.all(query)
      end
      def all!(_) do
        raise ArgumentError, message: "Invalid definition parameters passed to all!/0."
      end

      @doc """
      Find the record associated with the passed id.

      ## Examples
      iex> find!(1)
      Ecto.Schema.t | nil
      """
      @spec find!(Number.t) :: Ecto.Schema.t
      def find!(id) when is_integer(id) or is_binary(id) do
        # Execute the query with digesting the default criteria.
        query = from(s in @schema) |> where([s], s.id == ^id)

        # If this is a soft deleted schema, then we want to go ahead and apply
        # the filter automatically so dead data isnt returned.
        query = if soft_delete_enabled?(),
          do: where(query, [s], is_nil(field(s, ^Keyword.get(@schema_opts, :soft_delete)))),
        else: query

        @repository.one(query)
      end
      def find!(nil), do: nil
      def find!(_) do
        raise ArgumentError, message: "Invalid definition parameters passed to find!/1."
      end

      @doc """
      Based on the passed method parameters, we want to go ahead and
      issue an insert or an update depending on if the schema exists or not
      already.

      ## Examples
      iex> save!(nil, attrs)
      new_schema

      iex> save!(schema, attrs)
      updated_schema
      """
      @spec save!(Ecto.Schema.t, Map.t) :: Ecto.Schema.t
      def save!(_, attrs) when not is_map(attrs) do
        raise ArgumentError, message: "Invalid definition parameters passed to save!/2."
      end
      def save!(nil, attrs) do
        with %Ecto.Changeset{valid?: true} = changeset <- @schema.changeset(%@schema{}, attrs),
             created_schema <- @repository.insert!(changeset) do
          created_schema
        end
      end
      def save!(%@schema{} = existing, attrs) do
        with %Ecto.Changeset{valid?: true} = changeset <- @schema.changeset(existing, attrs),
             updated_schema <- @repository.update!(changeset) do
          updated_schema
        end
      end

      @doc """
      Based on the macro settings, as well as the passed schema; issue a delete
      request for the record (soft or hard) so that the schema is no longer
      active or available.

      ## Examples
      iex> delete!(schema)
      :ok
      """
      @spec delete!(Ecto.Schema.t) :: Ecto.Schema.t
      def delete!(%@schema{} = schema) do
        if soft_delete_enabled?(),
          do: @repository.update!(change(schema, deleted_at: soft_delete_timestamp!(:now))),
        else: @repository.delete!(schema)
      end
      def delete!(_) do
        raise ArgumentError, message: "Invalid definition parameters passed to delete!/1."
      end

      defoverridable find!: 1, save!: 2, delete!: 1

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
  This macro will allow us to handle and setup any options required
  for instantiation of this recipe. Specifically, this will instantiate
  the repo wrapper.

  ## Usage
  repo MyApplication.Repo
  """
  @spec repo(Ecto.Repo.t) :: none
  defmacro repo(repo) do
    quote do
      Module.put_attribute(__MODULE__, :repository, unquote(repo))
    end
  end

  @doc """
  This macro will allow us to handle and setup any options required
  for instantiation of this recipe. Specifically, this will instantiate
  the repo wrapper.

  ## Usage
  schema MyApplication.Schema, soft_delete?: true
  """
  @spec schema(Ecto.Schema.t, Keyword.t) :: none
  defmacro schema(schema, opts \\ []) do
    quote do
      Module.put_attribute(__MODULE__, :schema, unquote(schema))
      Module.put_attribute(__MODULE__, :schema_opts, unquote(opts))
    end
  end
end
