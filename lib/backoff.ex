defmodule Backoff do
  @moduledoc """
  Documentation for Backoff.

  ```
  Backoff.new(fn ->

  end)
  ```
  """
  require Logger

  @doc """
  Hello world.

  ## Examples

      iex> Backoff.hello
      :world

  """
  def hello do
    :world
  end

  @typedoc """
  Backoff options.
  """
  @type backoff_opts_t :: Keyword.t

  def new(func, args \\ [], opts \\ [])
  def new(func, args, opts) do
    default_opts = [
      debug: false,
      first_backoff: 100,
      max_backoff: 3000,
      max_retries: 25,
      on_success: fn(res) -> res end,
      on_error: fn(res) -> res end,
      choose_func: &default_choose_next/2,
    ]

    opts = Keyword.merge(default_opts, opts)

    {func, args, opts, %{
      backoff: opts[:first_backoff],
      attempts: 0,
    }}
  end

  def exec({func, args, opts, state}) do
    on_success = opts[:on_success]
    on_error = opts[:on_error]
    max_backoff = opts[:max_backoff]
    choose_next = opts[:choose_func]

    case apply(func, args) do
      {:error, err} -> on_error.({:error, err})
      res -> on_success.(res)
    end
    |> case do
      {:error, err} ->
        next_wait_ms = min(choose_next.(state, opts), max_backoff)
        Logger.debug([
          inspect(func), " failed: ", inspect(err), ". ",
          "Sleeping for ", to_string(next_wait_ms), " ms"
        ])
        Process.sleep(next_wait_ms)

        if retry?(state, opts) do
          exec({func, args, opts,
            %{state |
              attempts: state.attempts + 1,
              backoff: next_wait_ms,
            }})
        else
          Logger.debug([
            "Giving up ", inspect(func),
            " after ", to_string(state.attempts), " attempts.",
          ])
          {:error, err}
        end
      res -> res
    end
  end

  defp default_choose_next(%{backoff: backoff}, _opts), do: backoff * 2

  defp retry?(%{attempts: attempts}, opts) do
    attempts < opts[:max_retries]
  end
end
