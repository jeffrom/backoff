defmodule Backoff.Strategy.Define do
  @moduledoc """
  A backoff that uses a defined set of values.
  """
  @behaviour Backoff.Strategy

  @spec init(Backoff.opts_t) :: Backoff.Strategy.state_t | no_return
  def init(%{strategy_opts: opts}) do
    case Map.get(opts, :values) do
      vals when is_list(vals) -> vals
    end
  end

  @spec choose(Backoff.state_t, Backoff.opts_t)
  :: {non_neg_integer, Backoff.Strategy.state_t}
  def choose(%{attempts: attempts, strategy_data: choices}, _opts) do
    {Enum.at(choices, attempts) || List.last(choices), nil}
  end
end
