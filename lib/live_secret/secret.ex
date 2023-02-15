defmodule Bonfire.Encrypt.Secret do
  @moduledoc """
  A mixin that stores [metadata about] encrypted secrets
  """
  use Pointers.Mixin,
    otp_app: :bonfire_data_identity,
    source: "bonfire_encrypt_secret"

  import Ecto.Query, only: [from: 2]
  # import Untangle

  alias Bonfire.Encrypt.Secret
  alias Bonfire.Encrypt.Presecret
  alias Bonfire.Encrypt.PubSub
  alias Bonfire.Common.Repo

  @maxcontentsize 4096
  @ivsize 12

  # alias Ecto.Changeset

  mixin_schema do
    field :burn_key, :string, redact: true
    field :burned_at, :naive_datetime, default: nil
    field :content, :binary, redact: true
    field :iv, :binary, redact: true
    field :creator_key, :string, redact: true
    field :expires_at, :naive_datetime
  end

  def topic(id) do
    "secret/#{id}"
  end

  def count_secrets() do
    Repo.aggregate(from(_s in Secret, []), :count, :id)
  end

  @doc """
  Reads secret with id or throws
  """
  def get_secret!(id) do
    Repo.get!(Secret, id)
  end

  @doc """
  Reads secret with id or returns error
  """
  def get_secret(id) do
    Repo.get(Secret, id)
  end

  def new() do
    %Secret{}
  end

  @doc """
  Inserts secret or throws
  `presecret_attrs` is a map of attrs from the Presecret struct. We
  transform this into fields on the Secret. Easier to send base64 to
  to the browser with Presecret and store raw binary in the Secret.
  """
  def insert!(presecret_attrs) do
    attrs = Presecret.make_secret_attrs(presecret_attrs)

    Secret.new()
    |> Secret.changeset(attrs)
    |> Repo.insert!()
  end

  def burn!(secret, event_extra \\ []) do
    secret = %Secret{id: id, burned_at: burned_at} = do_burn!(secret)
    PubSub.notify_burned!(id, burned_at, event_extra)
    secret
  end

  @doc """
  Burns a secret or throws
  Burned secrets have no iv and no ciphertext
  """
  def do_burn!(secret) do
    burned_at = NaiveDateTime.utc_now()

    secret
    |> Secret.changeset(%{
      iv: nil,
      burned_at: burned_at,
      content: nil
    })
    |> Repo.update!()
  end

  @doc false
  def changeset(secret, attrs) do
    secret
    |> Ecto.Changeset.cast(attrs, [
      :id,
      :creator_key,
      :burn_key,
      :content,
      :iv,
      :burned_at,
      :expires_at
    ])
    |> Ecto.Changeset.validate_required([:creator_key, :expires_at])
    |> validate_content_size()
    |> validate_iv_size()
  end

  def validate_content_size(changeset) do
    validate_byte_size_less_equal(changeset, :content, @maxcontentsize)
  end

  defp validate_byte_size_less_equal(changeset, field, maxsize) do
    changeset
    |> Ecto.Changeset.validate_change(
      field,
      fn ^field, value ->
        if byte_size(value) > maxsize do
          [{field, "too big"}]
        else
          []
        end
      end
    )
  end

  def validate_iv_size(changeset) do
    validate_byte_size_equal(changeset, :iv, @ivsize)
  end

  defp validate_byte_size_equal(changeset, field, size) do
    changeset
    |> Ecto.Changeset.validate_change(
      field,
      fn ^field, value ->
        if byte_size(value) != size do
          [{field, "wrong size"}]
        else
          []
        end
      end
    )
  end
end
