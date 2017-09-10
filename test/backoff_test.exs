defmodule BackoffTest do
  use ExUnit.Case
  doctest Backoff

  test "works in simplest case" do
    res =
      Backoff.new()
      |> Backoff.exec(fn -> {:ok, :nice} end)

    assert res == {:ok, :nice}
  end

  test "works in error case" do
    res =
      Backoff.new(max_retries: 5, first_backoff: 0)
      |> Backoff.exec(fn -> {:error, :ohno} end, [])

    assert res == {:error, :ohno}
  end

  test "can override choosing next interval" do
    {res, state} =
      Backoff.new(
        max_retries: 5,
        first_backoff: 500,
        chooser: fn(_state, _opts) -> 0 end,
        debug: true)
        |> Backoff.exec(fn -> {:error, :ohno} end, [])

    assert res == {:error, :ohno}
    assert %{attempts: 5} = state
  end

  test "can override on_success function" do
    res =
      Backoff.new(first_backoff: 0,
                  max_retries: 5,
                  on_success: fn({:ok, :nice}) -> {:error, :cool} end)
      |> Backoff.exec(fn -> {:ok, :nice} end, [])

    assert res == {:error, :cool}
  end

  test "can override on_error function" do
    res =
      Backoff.new(first_backoff: 0,
                  max_retries: 5,
                  on_error: fn({:error, :cool}) -> {:ok, :nice} end)
      |> Backoff.exec(fn -> {:error, :cool} end, [])

    assert res == {:ok, :nice}
  end
end
