defmodule Backoff.Strategy.WindowTest.TestBackoff do
  @moduledoc false

  def init(%{strategy_opts: %{val: val}}), do: {%{}, %{val: val}}

  def choose(%{strategy_data: %{val: val}}, _), do: {0, %{val: val}}
end


defmodule Backoff.Strategy.WindowTest do
  use ExUnit.Case

  alias Backoff.Strategy.Window

  test "increments its counter on response" do
    {strategy_opts, strat} = Window.init(%{strategy_opts: %{}})
    opts = %{strategy_opts: strategy_opts}

    {_res, next_state} = Window.on_response(true, %{strategy_data: strat}, opts)
    assert %{value: 1} = next_state

    {_res, final_state} = Window.on_response(
      true, %{strategy_data: next_state}, opts)
    assert %{value: 2} = final_state
  end

  test "resets the window" do
    now = 1_500_500_000
    opts = %{strategy_opts: %{
      __now: now,
      window_size: 100,
    }}
    {_, strat} = Window.init(opts)

    opts = %{strategy_opts: %{
      __now: now + 150,
      window_size: 100,
    }}
    assert {:ok, next_state} = Window.before(%{strategy_data:
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
    now = 1_500_500_000
    opts = %{strategy_opts: %{
      __now: now,
      window_size: 100,
    }}
    {_, strat} = Window.init(opts)

    opts = %{strategy_opts: %{
      __now: now + 100,
      window_size: 100,
    }}
    {_, next_state} = Window.before(%{
      strategy_data: %{strat | error: :rate_limited}},
      opts)

    assert %{
      error: nil,
      curr: 1_500_500_100,
      next: 1_500_500_200,
    } = next_state
  end

  test "allows through requests when not rate limited" do
    now = 1_500_500_000
    opts = %{strategy_opts: %{
      __now: now,
      window_size: 100,
    }}
    {_, strat} = Window.init(opts)

    opts = %{strategy_opts: %{
      __now: now + 10,
      window_size: 100,
    }}
    {_, next_state} = Window.before(%{strategy_data: strat}, opts)

    assert %{curr: 1_500_500_000} = next_state
  end

  test "can override backoff strategy" do
    opts = %{strategy_opts: %{
      backoff: Backoff.Strategy.WindowTest.TestBackoff,
      backoff_opts: %{val: :siiick},
    }}
    {_, strat} = Window.init(opts)

    {0, next_state} = Window.choose(%{strategy_data: strat}, opts)
    assert %{
      strategy_data: %{
        backoff_data: %{val: :siiick}}} = next_state
  end

  test "default checker detects rate limit" do
    {strategy_opts, strat} = Window.init(%{strategy_opts: %{}})
    opts = %{strategy_opts: strategy_opts}

    {_res, next_state} = Window.on_response(
      {:ok, %{status_code: 429}}, %{strategy_data: strat}, opts)
    assert %{error: :rate_limited} = next_state
  end

  test "default checker returns results in normal case" do
    {strategy_opts, strat} = Window.init(%{strategy_opts: %{}})
    opts = %{strategy_opts: strategy_opts}

    {res, _next_state} = Window.on_response(
      {:ok, :cool}, %{strategy_data: strat}, opts)

    assert {:ok, :cool} = res
  end
end
