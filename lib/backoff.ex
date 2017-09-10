defmodule Backoff do
  @moduledoc """
  Documentation for Backoff.

  ```
  Backoff.new(fn ->

  end)
  ```
  """
  require Logger

  @typedoc """
  Backoff options.
  """
  @type backoff_opts_t :: Keyword.t

  def new(opts \\ []) do
    default_opts = [
      debug: false,
      first_backoff: 100,
      max_backoff: 3000,
      max_retries: 25,
      on_success: fn(res) -> res end,
      on_error: fn(res) -> res end,
      chooser: &default_chooser/2,
    ]

    opts =
      Keyword.merge(default_opts, opts)
      |> Map.new()

    {opts, %{
      backoff: opts.first_backoff,
      attempts: 0,
    }}
  end

  def exec({opts, state}, func, args \\ []) do
    do_exec(func, args, opts, state)
    |> do_result(opts)
  end

  defp do_exec(func, args, opts, state) do
    case apply(func, args) do
      {:error, err} -> opts.on_error.({:error, err})
      res -> opts.on_success.(res)
    end
    |> case do
      {:error, err} ->
        next_wait_ms = min(opts.chooser.(state, opts), opts.max_backoff)
        Logger.debug([
          inspect(func), " failed: ", inspect(err), ". ",
          "Sleeping for ", to_string(next_wait_ms), " ms"
        ])
        Process.sleep(next_wait_ms)

        if retry?(state, opts) do
          do_exec(func, args, opts,
                  %{state |
                    attempts: state.attempts + 1,
                    backoff: next_wait_ms,
                  })
        else
          Logger.debug([
            "Giving up ", inspect(func),
            " after ", to_string(state.attempts), " attempts.",
          ])
          {{:error, err}, state}
        end
      res -> {res, state}
    end
  end

  defp default_chooser(%{backoff: backoff}, _opts), do: backoff * 2

  defp retry?(%{attempts: attempts}, %{max_retries: max_retries}) do
    attempts < max_retries
  end

  defp do_result({res, _state}, %{debug: false}), do: res
  defp do_result({res, state}, %{debug: true}), do: {res, state}
end
