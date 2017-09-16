defmodule Backoff.Strategy do
  @moduledoc """
  Strategies return the number of milliseconds before the next attempt.
  """

  @callback init(Backoff.opts_t) :: {map, any} | no_return

  @callback choose(Backoff.state_t, Backoff.opts_t)
  :: {non_neg_integer, any}
end
