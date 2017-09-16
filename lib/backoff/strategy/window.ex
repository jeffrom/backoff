defmodule Backoff.Strategy.Window do
  @moduledoc """
  A backoff that respects rate limits within time windows.
  """
  require Logger
  @behaviour Backoff.Strategy

  defmodule State do
    @moduledoc false
    defstruct [curr: 0,
               next: 0,
               value: 0,
               error: nil,
               limit: 0,
               remaining: 0,
               backoff_data: nil]

    @type t :: %__MODULE__{
      curr: non_neg_integer,
      next: non_neg_integer,
      value: non_neg_integer,
      error: any,
      limit: non_neg_integer | nil,
      remaining: non_neg_integer | nil,
      backoff_data: any,
    }
  end

  @spec init(Backoff.opts_t) :: State.t
  def init(%{strategy_opts: opts} = global_opts) do
    default_opts = %{
      window_size: 60 * 15,
      checker: &default_checker/1,
      backoff: Backoff.Strategy.Exponential,
      backoff_opts: %{},
    }
    opts = Map.merge(default_opts, opts)

    now = now_ts(%{strategy_opts: opts})
    %State{
      curr: now,
      next: now + opts.window_size,
      value: 0,
      error: nil,
      limit: nil,
      remaining: nil,
      backoff_data: opts.backoff.init(
        Map.put(global_opts, :strategy_opts, opts.backoff_opts)),
    }
  end

  @spec choose(Backoff.state_t, Backoff.opts_t)
  :: {non_neg_integer, State.t}
  def choose(state, %{strategy_opts: %{backoff: strategy}} = opts)
  when is_atom(strategy)
  do
    {ms, next_state} = strategy.choose(
      %{state | strategy_data: state.strategy_data.backoff_data},
      %{opts | strategy_opts: opts.strategy_opts.backoff_opts})

    strategy_data = state.strategy_data
    final_state = %{state |
      strategy_data: %{strategy_data | backoff_data: next_state},
    }
    {ms, final_state}
  end
  def choose(%{strategy_data: d}, _opts), do: {0, d}

  @spec on_response(any, Backoff.state_t) :: {any, State.t}
  def on_response(res, %{strategy_data: %State{value: value} = state}) do
    {res, %State{state | value: value + 1}}
  end

  @spec before(Backoff.state_t, Backoff.opts_t) :: State.t
  def before(%{strategy_data: %State{} = state}, opts) do
    handle_window(state, opts, now_ts(opts))
  end

  defp handle_window(%State{next: next, error: :rate_limited} = state,
                     opts, now)
  do
    wait_ms = next - now
    Logger.debug(["Rate limit hit. waiting ", to_string(wait_ms), " ms"])
    if wait_ms > 0 do
      Process.sleep(wait_ms)
    end

    next_window(state, next, opts.strategy_opts)
    # %State{state | error: nil}
  end
  defp handle_window(%{next: next} = state, %{strategy_opts: opts}, now)
  when now >= next
  do
    next_window(state, next, opts)
  end
  defp handle_window(state, _opts, _now) do
    state
  end

  defp next_window(state, next, %{window_size: window_size}) do
    %State{state |
      curr: next,
      next: next + window_size,
      value: 0,
      error: nil,
      limit: nil,
      remaining: nil,
    }
  end

  defp now_ts(%{strategy_opts: %{__now: now}}), do: now
  defp now_ts(_opts), do: DateTime.utc_now() |> DateTime.to_unix()

  defp default_checker({:ok, %{status_code: status}}) when status == 429 do
    {:error, :rate_limited}
  end
  defp default_checker({:error, err}), do: {:error, err}
  defp default_checker(res), do: res
end
