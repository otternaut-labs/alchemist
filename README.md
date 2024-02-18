# Alchemist

---

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `alchemist` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:alchemist, "~> 0.1.0"}
  ]
end
```

## About

Alchemist is a collection of extensions for various repository methods that can be
injected into inheriting modules through macro instantiation. Alchemist works with 
all Ecto repository types, as well as all Ecto.Schema internal options that provide 
functionality.

## Usage

Add to your `mix.exs` file:

```elixir
defp deps do
  [
    {:alchemist, "~> 0.1.0"},
  ]
end
```

Then run `mix deps.get` in your shell to fetch the dependencies.

Finally, in the module definition, you will need to specify the required options in the setup macro.

```elixir
# In your application code.
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
```

## Important links

  * [Documentation](https://hexdocs.pm/alchemist)
  * [Examples](https://github.com/otternaut-labs/alchemist/tree/master/examples)

## License

Copyright (c) 2024 Otternaut Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at [https://www.apache.org/licenses/LICENSE-2.0](https://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

