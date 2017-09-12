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
end
