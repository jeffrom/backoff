defmodule Backoff.Strategy.Exponential do
  @moduledoc """
  A simple, incremental backoff.
  """
  @behaviour Backoff.Strategy

  @spec init(Backoff.opts_t) :: {map, any}
  def init(_opts), do: {%{}, nil}

  @spec choose(Backoff.state_t, Backoff.opts_t)
  :: {non_neg_integer, any}
  def choose(%{backoff: backoff}, _opts) do
    {backoff * 2, nil}
  end
end
