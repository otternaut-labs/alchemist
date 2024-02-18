defmodule Alchemist do
  @moduledoc ~S"""
  The Alchemist module provides additional functionality extensions to Ecto.

  The definition of Alchemist functionality is possible through the `setup/0`
  api. The default implementation will inject repository methods into the
  inheriting context.

  `setup/0` requires at minimum a `repo` and `schema` option to allow for all
  of the various recipes (context, pagination) to work successfully. The additional
  `pagination` macro will further inject pagination ability into the context.

  ## Example

      defmodule ExampleContext do
        use Alchemist

        setup do
          repo MyApp.Repo
          schema MyApp.Schema, soft_delete: :deleted_at
          pagination do
            size default: 20, max: 100
            sort on: [:column], default: :column
            filter on: [:column]
            query on: [:column]
            range on: [:inserted_at]
          end
        end
      end
  """
  defmacro __using__(_) do
    quote do
      import Alchemist, only: [setup: 1]
    end
  end

  @doc """
  Defines an alchemist context with the given options.

  A context is essentially a helper that will allow additional
  repository functionality to be injected in dynamically through
  the __using__ macro.

  Since this macro is a standalone, and error will be thrown if
  the required options are not setup.

  ## Required Options

      * `repo` - Sets the repository attribute to use when extending functionality.
      * `schema` - Sets the schema attribute, and allows for additional options like
          soft delete to automatically be used.

  **Notes:**

      * If no pagination macro is part of the setup options, then no pagination
        functionality will be included in the context. See Alchemist.Pagination
        for more information.
  """
  @spec setup(any()) :: none()
  defmacro setup(do: block) do
    exposed = quote do
      try do
        # Import the relevant setup macros that represent all of
        # the various recipe actions that can be applied.
        import Alchemist.Recipe.Context, only: [repo: 1, schema: 1, schema: 2]
        import Alchemist.Recipe.Pagination, only: [pagination: 1]

        # By unquoting the passed block, it will run the macros
        # underneath and allow us to evaluate the result. This will mean
        # we can perform validation on the resulting block.
        unquote(block)

        # Prevent instantiation if there is no schema attached
        # to this macro. Not having one prevents 100% of the functionality
        # in this wrapper.
        if is_nil(@repository) or is_nil(@schema) do
          raise RuntimeError,
            message: "A repository and schema module is required in order to instantiate an Alchemist context."
        end

        # Pull in the supporting functions through the wrapper for
        # alchemist. This will allow basic repo functions and more.
        use Alchemist.Recipe.Context
      after
        :ok
      end
    end

    quote do
      unquote(exposed)
    end
  end
end
