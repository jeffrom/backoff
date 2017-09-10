defmodule Backoff.Strategy.DefineTest do
  use ExUnit.Case

  alias Backoff.Strategy.Define

  test "chooses in order" do
    choices = [0, 1, 2, 3]
    {opts, state} = Backoff.new(
      strategy: Define,
      strategy_opts: %{values: choices})
    strategy = Define.init(%{strategy_opts: %{values: choices}})

    for i <- 0..5 do
      {choice, _strat} = Define.choose(%{state |
        attempts: i, strategy_data: strategy
      }, opts)
      assert choice == (Enum.at(choices, i) || List.last(choices))
    end
  end
end
