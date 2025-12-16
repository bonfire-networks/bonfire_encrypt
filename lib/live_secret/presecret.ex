defmodule Bonfire.Encrypt.Presecret do
  @moduledoc false

  @durations ["1h", "1d", "3d", "1w"]

  def supported_durations(), do: @durations

  defp duration_to_seconds("-1h"), do: -div(:timer.hours(1), 1000)
  defp duration_to_seconds("1h"), do: div(:timer.hours(1), 1000)
  defp duration_to_seconds("1d"), do: div(:timer.hours(24), 1000)
  defp duration_to_seconds("3d"), do: div(:timer.hours(24) * 3, 1000)
  defp duration_to_seconds("1w"), do: div(:timer.hours(24) * 7, 1000)
end
