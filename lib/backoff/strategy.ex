defmodule Backoff.Strategy do
  @moduledoc """
  Strategies return the number of milliseconds before the next attempt.
  """

  @type state_t :: any

  @callback init(Backoff.opts_t) :: state_t

  @callback choose(Backoff.state_t, Backoff.opts_t)
  :: {non_neg_integer, state_t}
end
