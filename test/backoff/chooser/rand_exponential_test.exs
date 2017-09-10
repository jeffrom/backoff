defmodule Backoff.Strategy.RandExponentialTest do
  use ExUnit.Case

  alias Backoff.Strategy.RandExponential

  test "stays within bounds" do
    {opts, state} = Backoff.new(
      strategy: RandExponential,
      max_backoff: 3000,
      first_backoff: 100,
    )
    strategy = RandExponential.init(opts)
    allowed_choices = Enum.take(strategy, 2)

    0..50
    |> Enum.map(fn(_attempt) ->
      {choice, _strategy} = RandExponential.choose(%{ state |
        attempts: 2,
      }, opts)
      assert choice in allowed_choices
    end)
  end
end
