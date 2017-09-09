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

  def new(func, args \\ [], opts \\ [])
  def new(func, args, opts) do
    default_opts = [
      debug: false,
      first_backoff: 100,
      max_backoff: 3000,
      max_retries: 25,
      on_success: fn(res) -> res end,
      on_error: fn(res) -> res end,
      chooser: &default_chooser/1,
    ]

    opts = Keyword.merge(default_opts, opts)

    {func, args, opts, %{
      backoff: opts[:first_backoff],
      attempts: 0,
    }}
  end

  def exec({func, args, opts, state}) do
    debug? = opts[:debug]
    on_success = opts[:on_success]
    on_error = opts[:on_error]
    max_backoff = opts[:max_backoff]
    max_retries = opts[:max_retries]
    chooser = opts[:chooser]

    do_exec(func, args,
            debug?,
            on_success, on_error,
            max_backoff, max_retries,
            chooser,
            state)
    |> do_result(debug?)
  end

  defp do_exec(func, args,
               debug?,
               on_success, on_error,
               max_backoff, max_retries,
               chooser,
               state) do
    case apply(func, args) do
      {:error, err} -> on_error.({:error, err})
      res -> on_success.(res)
    end
    |> case do
      {:error, err} ->
        next_wait_ms = min(chooser.(state.backoff), max_backoff)
        Logger.debug([
          inspect(func), " failed: ", inspect(err), ". ",
          "Sleeping for ", to_string(next_wait_ms), " ms"
        ])
        Process.sleep(next_wait_ms)

        if retry?(state, max_retries) do
          do_exec(func, args,
                  debug?,
                  on_success, on_error,
                  max_backoff, max_retries,
                  chooser,
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

  defp default_chooser(backoff), do: backoff * 2

  defp retry?(%{attempts: attempts}, max_retries) do
    attempts < max_retries
  end

  defp do_result({res, _state}, false), do: res
  defp do_result({res, state}, true), do: {res, state}
end
