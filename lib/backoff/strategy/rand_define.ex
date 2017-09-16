defmodule Backoff.Strategy.RandDefine do
  @moduledoc """
  A backoff that uses a defined set of values with jitter.
  """
  @behaviour Backoff.Strategy

  @type opts_t :: %{
    values: [non_neg_integer]
  }

  @spec init(Backoff.opts_t) :: {opts_t, [non_neg_integer]} | no_return
  def init(%{strategy_opts: opts}) do
    state =
      case Map.get(opts, :values) do
        vals when is_list(vals) -> vals
      end
    {opts, state}
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
