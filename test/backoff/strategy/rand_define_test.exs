defmodule Backoff.Strategy.RandDefineTest do
  use ExUnit.Case

  alias Backoff.Strategy.RandDefine

  test "chooses in order" do
    choices = [0, 1, 2, 3, 4, 5]
    {opts, state} = Backoff.new(
      strategy: RandDefine,
      strategy_opts: %{values: choices})

    {_strategy_opts, strategy} = RandDefine.init(opts)

    for i <- 0..50 do
      {choice, _strat} = RandDefine.choose(%{state |
        attempts: i, strategy_data: strategy
      }, opts)
      assert choice in choices
    end
  end
end
