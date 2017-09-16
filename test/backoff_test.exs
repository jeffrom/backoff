defmodule BackoffTest.ZeroStrategy do
  @moduledoc false

  def init(_opts), do: nil

  def choose(_, _), do: {0, nil}
end

defmodule BackoffTest.TestStrategy do
  @moduledoc false

  def init(%{strategy_opts: %{val: val}}), do: %{val: val}

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

  test "can override choosing next interval" do
    {res, state} =
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
    {res, state} =
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

  test "can override on_success function" do
    res =
      [first_backoff: 0,
       max_retries: 5,
       on_success: fn({:ok, :nice}, _s, _opts) ->
         {{:error, :cool}, nil} end]
      |> Backoff.new()
      |> Backoff.run(fn -> {:ok, :nice} end, [])

    assert res == {:error, :cool}
  end

  test "can override on_error function" do
    res =
      [first_backoff: 0,
       max_retries: 5,
       on_error: fn({:error, :cool}, _s, _opts) ->
         {{:ok, :nice}, nil} end]
      |> Backoff.new()
      |> Backoff.run(fn -> {:error, :cool} end, [])

    assert res == {:ok, :nice}
  end

  test "success callback can update meta state" do
    assert {_res, state} =
      [debug: true,
       first_backoff: 0,
       max_retries: 5,
       on_success: fn({:ok, :nice}, _state, _opts) ->
         {{:error, :cool}, %{cool: :wow}}
       end]
      |> Backoff.new()
      |> Backoff.run(fn -> {:ok, :nice} end)

    assert %{meta: %{cool: :wow}} = state
  end

  test "error callback can update meta state" do
    assert {_res, state} =
      [debug: true,
       first_backoff: 0,
       max_retries: 5,
       on_error: fn({:error, :cool}, _state, _opts) ->
         {{:ok, :nice}, %{cool: :wow}}
       end]
      |> Backoff.new()
      |> Backoff.run(fn -> {:error, :cool} end)

    assert %{meta: %{cool: :wow}} = state
  end
end
