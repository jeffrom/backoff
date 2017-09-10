defmodule Backoff do
  @moduledoc """
  Documentation for Backoff.
  """
  require Logger

  @typedoc """
  Backoff options.
  """
  @type opts_t :: %{
    debug: boolean,
    first_backoff: non_neg_integer,
    max_backoff: non_neg_integer,
    max_retries: non_neg_integer,
    on_success: ((any) -> {:error, any} | any),
    on_error: (({:error, any}) -> {:error, any} | any),
    strategy: module,
  }

  @typedoc """
  Backoff internal state.
  """
  @type state_t :: %{
    backoff: non_neg_integer,
    attempts: non_neg_integer,
    strategy_data: Backoff.Strategy.state_t,
  }

  @spec new(Keyword.t) :: {opts_t, state_t}
  def new(opts \\ []) do
    default_opts = [
      debug: false,
      first_backoff: 100,
      max_backoff: 3000,
      max_retries: 25,
      on_success: &default_after/1,
      on_error: &default_after/1,
      strategy: Backoff.Strategy.Exponential,
    ]

    opts =
      default_opts
      |> Keyword.merge(opts)
      |> Map.new()

    {opts, %{
      backoff: opts.first_backoff,
      attempts: 0,
      strategy_data: opts.strategy.init(opts),
    }}
  end

  @spec run({opts_t, state_t}, (... -> any), [any]) :: {:error, any} | any
  def run({opts, state}, func, args \\ []) do
    func
    |> do_run(args, opts, state)
    |> do_result(opts)
  end

  defp do_run(func, args, opts, state) do
    func
    |> apply(args)
    |> do_afters(opts)
    |> case do
      {:error, err} ->
        {next_backoff, strategy_data} = opts.strategy.choose(state, opts)
        next_wait_ms = min(next_backoff, opts.max_backoff)
        Logger.debug([
          inspect(func), " failed: ", inspect(err), ". ",
          "Sleeping for ", to_string(next_wait_ms), " ms"
        ])
        Process.sleep(next_wait_ms)

        if retry?(state, opts) do
          do_run(func, args, opts, %{state |
            attempts: state.attempts + 1,
            backoff: next_wait_ms,
            strategy_data: strategy_data
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

  defp do_afters({:error, err}, %{on_error: on_error}) do
    on_error.({:error, err})
  end
  defp do_afters(res, %{on_success: on_success}), do: on_success.(res)

  defp default_after(res), do: res

  defp retry?(%{attempts: attempts}, %{max_retries: max_retries}) do
    attempts < max_retries
  end

  defp do_result({res, _state}, %{debug: false}), do: res
  defp do_result({res, state}, %{debug: true}), do: {res, state}
end
