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
               remaining: 0]

    @type t :: %__MODULE__{
      curr: non_neg_integer,
      next: non_neg_integer,
      value: non_neg_integer,
      error: any,
      limit: non_neg_integer | nil,
      remaining: non_neg_integer | nil,
    }
  end

  @spec init(Backoff.opts_t) :: State.t
  def init(%{strategy_opts: opts}) do
    opts = Map.merge(%{
      window_size: 60 * 15,
      checker: &default_checker/1,
    }, opts)

    now = now_ts()
    %State{
      curr: now,
      next: now + opts.window_size,
      value: 0,
      error: nil,
      limit: nil,
      remaining: nil,
    }
  end

  @spec choose(Backoff.state_t, Backoff.opts_t)
  :: {non_neg_integer, State.t}
  def choose(%{strategy_data: d}, _opts) do
    # %{curr: curr, next: next, value: value} = d
    {0, d}
  end

  @spec on_response(any, Backoff.state_t) :: {any, State.t}
  def on_response(res, %{strategy_data: %State{value: value} = state}) do
    {res, %State{state | value: value + 1}}
  end

  @spec before(Backoff.state_t, Backoff.opts_t) :: State.t
  def before(%{strategy_data: %State{} = state}, opts) do
    handle_window(state, opts, now_ts())
  end

  defp handle_window(%State{next: next, error: :rate_limited} = state,
                     opts, now)
  do
    wait_ms = next - now
    if wait_ms > 0 do
      Logger.debug(["Rate limit hit. waiting ", to_string(wait_ms), " ms"])
      Process.sleep(wait_ms)
    end

    %State{state | error: nil}
  end
  defp handle_window(%{next: next} = state, opts, now) when now >= next do
    %State{state |
      curr: next,
      next: next + opts.window_size,
      value: 0,
      error: nil,
      limit: nil,
      remaining: nil,
    }
  end
  defp handle_window(state, _opts, _now) do
    state
  end

  defp now_ts do
    DateTime.utc_now() |> DateTime.to_unix()
  end

  defp default_checker({:ok, %{status_code: status}}) when status == 429 do
    {:error, :rate_limited}
  end
  defp default_checker({:error, err}), do: {:error, err}
  defp default_checker(res), do: res
end
