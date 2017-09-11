defmodule Backoff.Strategy.RandDefine do
  @moduledoc """
  A backoff that uses a defined set of values with jitter.
  """
  @behaviour Backoff.Strategy

  @spec init(Backoff.opts_t) :: any | no_return
  def init(%{strategy_opts: opts}) do
    case Map.get(opts, :values) do
      vals when is_list(vals) -> vals
    end
  end

  @spec choose(Backoff.state_t, Backoff.opts_t)
  :: {non_neg_integer, any}
  def choose(%{attempts: attempts, strategy_data: choices}, _opts) do
    choice =
      choices
      |> Enum.take(max(attempts, 1))
      |> Enum.random()
    {choice, nil}
  end
end
