defmodule Alchemist do
  @moduledoc false
  defmacro __using__(_) do
    quote do
      import Alchemist, only: [setup: 1]
    end
  end

  @doc """
  This wrapper is a macro for instantiation of this module. This will
  allow us to configure and setup individual contexts with added
  syntactic sugar and methods.

  ## Usage
  setup do
    repo ...
    schema ...
  end
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
