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
    before_request: ((opts_t, state_t) -> {:error, any} | any),
    on_success: ((any, state_t) -> {{:error, any} | any, meta_t}),
    on_error: (({:error, any}, state_t) -> {{:error, any} | any, meta_t}),
    strategy: module,
    strategy_opts: map,
  }

  @typedoc """
  Backoff internal state.
  """
  @type state_t :: %{
    backoff: non_neg_integer,
    attempts: non_neg_integer,
    strategy_data: Backoff.Strategy.state_t,
    meta: meta_t,
  }

  @type meta_t :: map

  @spec new(Keyword.t) :: {opts_t, state_t}
  def new(opts \\ []) do
    default_opts = [
      debug: false,
      first_backoff: 100,
      max_backoff: 3000,
      max_retries: 25,
      before_request: &default_before/2,
      on_success: &default_after/2,
      on_error: &default_after/2,
      strategy: Backoff.Strategy.Exponential,
      strategy_opts: %{},
    ]

    opts =
      default_opts
      |> Keyword.merge(opts)
      |> Map.new()

    {opts, %{
      backoff: opts.first_backoff,
      attempts: 0,
      strategy_data: opts.strategy.init(opts),
      meta: %{},
    }}
  end

  @spec run({opts_t, state_t}, (... -> any), [any]) :: {:error, any} | any
  def run({opts, state}, func, args \\ []) do
    {opts, state}
    |> do_run(func, args)
    |> do_result(opts)
  end

  defp do_run({opts, state}, func, args) do
    {opts, state}
    |> do_befores()
    |> case do
      {:error, _err} = err_res -> err_res
      _res -> apply(func, args)
    end
    |> do_afters(opts, state)
    |> case do
      {{:error, err}, new_meta} ->
        state = update_meta(state, new_meta)
        {next_backoff, strategy_data} = opts.strategy.choose(state, opts)
        next_wait_ms = min(next_backoff, opts.max_backoff)
        Logger.debug([
          inspect(func), " failed: ", inspect(err), ". ",
          "Sleeping for ", to_string(next_wait_ms), " ms"
        ])
        Process.sleep(next_wait_ms)

        if retry?(state, opts) do
          do_run({opts, %{state |
            attempts: state.attempts + 1,
            backoff: next_wait_ms,
            strategy_data: strategy_data
          }}, func, args)
        else
          Logger.debug([
            "Giving up ", inspect(func),
            " after ", to_string(state.attempts), " attempts.",
          ])
          {{:error, err}, state}
        end
      {res, new_meta} ->
        {res, update_meta(state, new_meta)}
    end
  end

  defp do_befores({opts, state}) do
    next_state = opts.before_request.(opts, state)
    {opts, %{state | strategy_data: next_state}}
  end

  defp do_afters({:error, err}, %{on_error: on_error}, state) do
    on_error.({:error, err}, state)
  end
  defp do_afters(res, %{on_success: on_success}, state) do
    on_success.(res, state)
  end

  defp default_before(_opts, _state), do: :ok

  defp default_after(res, _state), do: {res, nil}

  defp retry?(%{attempts: attempts}, %{max_retries: max_retries}) do
    attempts < max_retries
  end

  defp do_result({res, _state}, %{debug: false}), do: res
  defp do_result({res, state}, %{debug: true}), do: {res, state}

  defp update_meta(state, nil), do: state
  defp update_meta(state, new_meta) do
    %{state | meta: Map.merge(state.meta, new_meta)}
  end
end
