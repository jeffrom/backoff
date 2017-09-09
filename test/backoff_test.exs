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
end
