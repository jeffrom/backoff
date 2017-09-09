defmodule BackoffTest do
  use ExUnit.Case
  doctest Backoff

  test "works in simplest case" do
    res =
      Backoff.new(fn -> {:ok, :nice} end)
      |> Backoff.exec()

    assert res == {:ok, :nice}
  end

  test "works in error case" do
    res =
      Backoff.new(fn -> {:error, :ohno} end, [],
                  max_retries: 5, first_backoff: 0)
      |> Backoff.exec()

    assert res == {:error, :ohno}
  end

  test "can override choosing next interval" do
    {res, state} =
      Backoff.new(
        fn -> {:error, :ohno} end, [],
        max_retries: 5,
        first_backoff: 500,
        chooser: fn(_backoff) -> 0 end,
        debug: true)
        |> Backoff.exec()

    assert res == {:error, :ohno}
    assert %{attempts: 5} = state
  end

  test "can override on_success function" do
    res =
      Backoff.new(fn -> {:ok, :nice} end, [],
                  first_backoff: 0,
                  max_retries: 5,
                  on_success: fn({:ok, :nice}) -> {:error, :cool} end)
      |> Backoff.exec()

    assert res == {:error, :cool}
  end

  test "can override on_error function" do
    res =
      Backoff.new(fn -> {:error, :cool} end, [],
                  first_backoff: 0,
                  max_retries: 5,
                  on_error: fn({:error, :cool}) -> {:ok, :nice} end)
      |> Backoff.exec()

    assert res == {:ok, :nice}
  end
end
