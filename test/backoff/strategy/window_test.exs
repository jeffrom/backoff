defmodule Backoff.Strategy.WindowTest do
  use ExUnit.Case

  alias Backoff.Strategy.Window

  test "increments its counter on response" do
    strat = Window.init(%{strategy_opts: %{}})

    {_res, next_state} = Window.on_response(true, %{strategy_data: strat})
    assert %{value: 1} = next_state

    {_res, final_state} = Window.on_response(true, %{strategy_data: next_state})
    assert %{value: 2} = final_state
  end

  test "resets the window" do
    now = 1_500_500_000
    opts = %{strategy_opts: %{
      __now: now,
      window_size: 100,
    }}
    strat = Window.init(opts)

    opts = %{strategy_opts: %{
      __now: now + 150,
      window_size: 100,
    }}
    next_state = Window.before(%{strategy_data:
      %{strat | value: 10}}, opts)

    assert %{
      value: 0,
      curr: 1_500_500_100,
      next: 1_500_500_200,
      error: nil,
      limit: nil,
      remaining: nil,
    } = next_state
  end

  test "resets rate limiting errors" do

  end
end
