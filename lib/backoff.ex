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
    before_request: ((state_t, opts_t) ->
                      {{:error, any} | any, meta_t}),
    after_request: ((any, state_t, opts_t) ->
                  {{:error, any} | any, meta_t}),
    strategy: module,
    strategy_opts: map,
    single: boolean,
  }

  @typedoc """
  Backoff internal state.
  """
  @type state_t :: %{
    backoff: non_neg_integer,
    prev_backoff: non_neg_integer,
    attempts: non_neg_integer,
    strategy_data: any,
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
      after_request: &default_after/3,
      strategy: Backoff.Strategy.Exponential,
      strategy_opts: %{},
    ]

    opts =
      default_opts
      |> Keyword.merge(opts)
      |> Map.new()

    {strategy_opts, strategy_data} = opts.strategy.init(opts)

    {%{opts | strategy_opts: strategy_opts}, %{
      backoff: opts.first_backoff,
      prev_backoff: 0,
      attempts: 0,
      strategy_data: strategy_data,
      meta: %{},
    }}
  end

  @spec run({opts_t, state_t}, (... -> any), [any]) :: {:error, any} | any
  def run({opts, state}, func, args \\ []) do
    {Map.put(opts, :single, false), state}
    |> one(func, args)
    |> finish()
  end

  @spec one({opts_t, state_t}, (... -> any), [any])
  :: {any, {opts_t, state_t}}
  def one({opts, state}, func, args \\ []) do
    {opts, state}
    |> do_befores()
    |> case do
      {{:error, _err} = err_res, _s} -> {:done, err_res}
      _res -> apply(func, args)
    end
    |> do_afters(opts, state)
    |> case do
      {{:done, res}, new_meta} -> {res, {opts, update_meta(state, new_meta)}}
      {{:error, err}, new_meta} ->
        state = update_meta(state, new_meta)
        %{attempts: attempts} = state

        {next_backoff, strategy_data} = opts.strategy.choose(state, opts)
        next_wait_ms = min(next_backoff, opts.max_backoff)
        Logger.debug([
          inspect(func), " failed: ", inspect(err), ". ",
          "Sleeping for ", to_string(next_wait_ms), " ms"
        ])
        handle_sleep(next_wait_ms, opts)

        ns = next_state(state, next_wait_ms, strategy_data)
        if retry?(state, opts) do
          one({opts, ns}, func, args)
        else
          Logger.debug([
            "Giving up ", inspect(func),
            " after ", to_string(attempts), " attempts.",
          ])
          {{:error, err}, {opts, ns}}
        end
      {res, new_meta} ->
        {res, {opts, update_meta(state, new_meta)}}
    end
  end

  @spec finish({any, {opts_t, state_t}}) :: any | {any, {opts_t, state_t}}
  def finish({res, {%{debug: true} = opts, state}}), do: {res, {opts, state}}
  def finish({res, {%{single: true} = opts, state}}), do: {res, {opts, state}}
  def finish({res, {%{debug: false}, _state}}), do: res

  defp handle_sleep(next_wait_ms, %{single: false}) do
    Process.sleep(next_wait_ms)
  end
  defp handle_sleep(_ms, _opts), do: nil

  defp do_befores({opts, state}) do
    {res, next_state} = opts.before_request.(state, opts)
    {res, %{state | strategy_data: next_state}}
  end

  defp do_afters({:done, _} = res, _opts, state) do
    {res, state.meta}
  end
  defp do_afters(res, %{after_request: after_request} = opts, state) do
    after_request.(res, state, opts)
  end

  defp default_before(state, _opts), do: {:ok, state}

  defp default_after(res, state, _opts), do: {res, state.meta}

  defp retry?(%{attempts: attempts},
              %{single: false, max_retries: max_retries})
  do
    attempts + 1 < max_retries
  end
  defp retry?(_s, _opts), do: false

  defp update_meta(state, nil), do: state
  defp update_meta(state, new_meta) do
    %{state | meta: Map.merge(state.meta, new_meta)}
  end

  defp next_state(state, next_wait_ms, strategy_data) do
    %{attempts: attempts, backoff: backoff} = state
    %{state |
      attempts: attempts + 1,
      prev_backoff: backoff,
      backoff: next_wait_ms,
      strategy_data: strategy_data,
    }
  end
end
