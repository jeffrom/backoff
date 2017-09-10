defmodule Backoff.Chooser.RandExponentialTest do
  use ExUnit.Case

  alias Backoff.Chooser.RandExponential

  test "stays within bounds" do
    {opts, state} = Backoff.new(
      chooser: RandExponential,
      max_backoff: 3000,
      first_backoff: 100,
    )
    chooser = RandExponential.init(opts)
    allowed_choices = Enum.take(chooser, 2)

    0..50
    |> Enum.map(fn(_attempt) ->
      {choice, _chooser} = RandExponential.choose(%{ state |
        attempts: 2,
      }, opts)
      assert choice in allowed_choices
    end)
  end
end
