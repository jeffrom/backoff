defmodule Backoff.Strategy.RandExponential do
  @moduledoc """
  Randomly chooses an interval within the exponential range.
  """
  @behaviour Backoff.Strategy

  @type choices_t :: [non_neg_integer]

  @spec init(Backoff.opts_t) :: choices_t
  def init(%{max_backoff: ceiling, first_backoff: first}) do
    build_choices([first], ceiling)
  end

  @spec choose(Backoff.state_t, Backoff.opts_t)
  :: {non_neg_integer, Backoff.Strategy.state_t}
  def choose(%{strategy_data: choices, attempts: attempts}, _opts) do
    choice =
      choices
      |> Enum.take(max(1, attempts))
      |> Enum.random()
    {choice, choices}
  end

  defp build_choices([h | t], ceiling) when h > ceiling do
    Enum.reverse(t)
  end
  defp build_choices([h | t], ceiling) do
    next = [h | t]
    build_choices([h * 2 | next], ceiling)
  end
end
