defmodule Backoff.Strategy.Define do
  @moduledoc """
  A backoff that uses a defined set of values.
  """
  @behaviour Backoff.Strategy

  @type opts_t :: %{
    values: [non_neg_integer]
  }

  @spec init(Backoff.opts_t) :: {opts_t, any} | no_return
  def init(%{strategy_opts: opts}) do
    vals =
      case Map.get(opts, :values) do
        vals when is_list(vals) -> vals
      end
    {opts, vals}
  end

  @spec choose(Backoff.state_t, Backoff.opts_t)
  :: {non_neg_integer, any}
  def choose(%{attempts: attempts, strategy_data: choices}, _opts) do
    {Enum.at(choices, attempts) || List.last(choices), nil}
  end
end
