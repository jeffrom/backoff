defmodule BackoffTest.ZeroStrategy do
  @moduledoc false

  def init(_opts), do: {%{}, nil}

  def choose(_, _), do: {0, nil}
end

defmodule BackoffTest.TestStrategy do
  @moduledoc false

  def init(%{strategy_opts: %{val: val}}), do: {%{}, %{val: val}}

  def choose(%{strategy_data: %{val: val}}, _), do: {0, %{val: val}}
end

defmodule BackoffTest do
  use ExUnit.Case
  doctest Backoff

  test "works in simplest case" do
    res =
      Backoff.new()
      |> Backoff.run(fn -> {:ok, :nice} end)

    assert res == {:ok, :nice}
  end

  test "works in error case" do
    res =
      [max_retries: 5, first_backoff: 0]
      |> Backoff.new()
      |> Backoff.run(fn -> {:error, :ohno} end, [])

    assert res == {:error, :ohno}
  end

  test "can override choosing next wait interval" do
    {res, {_opts, state}} =
      [max_retries: 5,
       first_backoff: 500,
       strategy: BackoffTest.ZeroStrategy,
       debug: true]
       |> Backoff.new()
       |> Backoff.run(fn -> {:error, :ohno} end, [])

    assert res == {:error, :ohno}
    assert %{attempts: 5} = state
  end

  test "can override choosing next interval with options" do
    {res, {_opts, state}} =
      [max_retries: 5,
       first_backoff: 500,
       strategy: BackoffTest.TestStrategy,
       strategy_opts: %{val: :niiice},
       debug: true]
       |> Backoff.new()
       |> Backoff.run(fn -> {:error, :ohno} end, [])

    assert res == {:error, :ohno}
    assert %{strategy_data: %{val: :niiice}} = state
  end

  test "can override after_request function when successful" do
    res =
      [first_backoff: 0,
       max_retries: 5,
       after_request: fn({:ok, :nice}, _s, _opts) ->
         {{:error, :cool}, nil} end]
      |> Backoff.new()
      |> Backoff.run(fn -> {:ok, :nice} end, [])

    assert res == {:error, :cool}
  end

  test "can override after_request function when erroring" do
    res =
      [first_backoff: 0,
       max_retries: 5,
       after_request: fn({:error, :cool}, _s, _opts) ->
         {{:ok, :nice}, nil} end]
      |> Backoff.new()
      |> Backoff.run(fn -> {:error, :cool} end, [])

    assert res == {:ok, :nice}
  end

  test "success callback can update meta state" do
    assert {_res, {_opts, state}} =
      [debug: true,
       first_backoff: 0,
       max_retries: 5,
       after_request: fn({:ok, :nice}, _state, _opts) ->
         {{:error, :cool}, %{cool: :wow}}
       end]
      |> Backoff.new()
      |> Backoff.run(fn -> {:ok, :nice} end)

    assert %{meta: %{cool: :wow}} = state
  end

  test "error callback can update meta state" do
    assert {_res, {_opts, state}} =
      [debug: true,
       first_backoff: 0,
       max_retries: 5,
       after_request: fn({:error, :cool}, _state, _opts) ->
         {{:ok, :nice}, %{cool: :wow}}
       end]
      |> Backoff.new()
      |> Backoff.run(fn -> {:error, :cool} end)

    assert %{meta: %{cool: :wow}} = state
  end

  test "doesn't apply if the before callback returns an error" do
    assert {{:error, :nice}, _state} =
      [debug: true,
       first_backoff: 0,
       max_retries: 5,
       before_request: fn(s, _o) -> {{:error, :nice}, s} end]
       |> Backoff.new()
       |> Backoff.run(fn -> {:ok, :cool} end)
  end

  test "can do one attempt at a time" do
    backoff = Backoff.new(single: true, first_backoff: 5, max_retries: 5)

    {res, {_opts, state}} = Backoff.one(backoff, fn -> {:error, :dang} end)
    assert {:error, :dang} = res
    assert %{attempts: 1, backoff: 10, prev_backoff: 5} = state
  end

  describe "exponential strategy" do
    test "works in successful case" do
      b = Backoff.new(strategy: Backoff.Strategy.Exponential)
      assert {:ok, :cool} = Backoff.run(b, fn -> {:ok, :cool} end)
    end

    test "works in error case" do
      b = Backoff.new(strategy: Backoff.Strategy.Exponential, max_retries: 3,
                      first_backoff: 1, debug: true)
      assert {{:error, :sick}, {_opts, state}} = Backoff.run(b, fn ->
        {:error, :sick}
      end)

      assert %{attempts: 3, backoff: 8, prev_backoff: 4} = state
    end
  end

  describe "define strategy" do
    test "works in successful case" do
      b = Backoff.new(strategy: Backoff.Strategy.Define, strategy_opts: %{
        values: [0, 1, 2],
      })
      assert {:ok, :cool} = Backoff.run(b, fn -> {:ok, :cool} end)
    end

    test "works in error case" do
      b = Backoff.new(strategy: Backoff.Strategy.Define, strategy_opts: %{
        values: [0, 1, 2],
      }, max_retries: 3, debug: true)

      assert {{:error, :sick}, {_opts, state}} = Backoff.run(b, fn ->
        {:error, :sick}
      end)

      assert %{attempts: 3, backoff: 2, prev_backoff: 1} = state
    end
  end
end
