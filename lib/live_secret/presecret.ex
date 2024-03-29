defmodule Bonfire.Encrypt.Presecret do
  use Ecto.Schema

  alias Bonfire.Encrypt.{OperationalKey, Presecret}

  @durations ["1h", "1d", "3d", "1w"]

  schema "presecrets" do
    field :burn_key, :string, redact: true
    field :content, :string, redact: true
    field :iv, :string, redact: true
    field :duration, :string, default: "1h"
  end

  def new() do
    %Presecret{
      burn_key: OperationalKey.generate(),
      iv: :base64.encode(:crypto.strong_rand_bytes(12))
    }
  end

  @doc """
  Returns a changeset with validated fields (or not) from Presecret attrs
  """
  def validate_presecret(presecret_attrs) do
    %Presecret{}
    |> Presecret.changeset(presecret_attrs)
    |> Map.put(:action, :validate)
  end

  # TODO - this can be done purely with changesets, I'm sure of it
  def make_secret_attrs(
        attrs = %{
          "burn_key" => burn_key,
          "content" => content,
          "iv" => iv,
          "duration" => duration
        }
      ) do
    now = NaiveDateTime.utc_now(Calendar.ISO)

    %{
      id: attrs["id"] || generate_id(),
      content: :base64.decode(content),
      iv: :base64.decode(iv),
      creator_key: OperationalKey.generate(),
      burn_key: burn_key,
      expires_at: NaiveDateTime.add(now, duration_to_seconds(duration))
    }
  end

  defp generate_id do
    Needle.Pointer.create(Bonfire.Data.Social.Message)
    |> Bonfire.Common.Repo.insert!()
    |> Map.get(:id)
  end

  def supported_durations(), do: @durations

  defp duration_to_seconds("-1h"), do: -div(:timer.hours(1), 1000)
  defp duration_to_seconds("1h"), do: div(:timer.hours(1), 1000)
  defp duration_to_seconds("1d"), do: div(:timer.hours(24), 1000)
  defp duration_to_seconds("3d"), do: div(:timer.hours(24) * 3, 1000)
  defp duration_to_seconds("1w"), do: div(:timer.hours(24) * 7, 1000)

  def changeset(presecret, params) do
    presecret
    |> Ecto.Changeset.cast(params, [:burn_key, :content, :iv, :duration])
    |> Ecto.Changeset.validate_required([:burn_key, :content, :iv, :duration])
    |> Ecto.Changeset.validate_inclusion(:duration, @durations)
  end
end
