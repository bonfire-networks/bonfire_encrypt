defmodule Bonfire.Encrypt.Secret do
  @moduledoc """
  Stores encrypted OpenMLS messages and related metadata.
  - `content`: OpenMLS ciphertext (binary)
  - `creator_key`: Sender's OpenMLS public key (hex/base64 string)
  - `expires_at`: Optional expiration timestamp
  """
  use Needle.Mixin,
    otp_app: :bonfire_data_identity,
    source: "bonfire_encrypt_secret"

  import Ecto.Query, only: [from: 2]
  # import Untangle

  alias Bonfire.Encrypt.Secret
  alias Bonfire.Encrypt.PubSub
  alias Bonfire.Common.Repo

  @maxcontentsize 4096

  # alias Ecto.Changeset

  mixin_schema do
    # OpenMLS ciphertext
    field :content, :binary, redact: true
    # Sender's OpenMLS public key
    field :creator_key, :string, redact: true
    # Optional
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
  Inserts secret or throws. Accepts a map of attributes.
  """
  def insert!(attrs) do
    Secret.new()
    |> Secret.changeset(attrs)
    |> Repo.insert!()
  end

  @doc false
  def changeset(secret, attrs) do
    secret
    |> Ecto.Changeset.cast(attrs, [
      :id,
      :creator_key,
      :content,
      :expires_at
    ])
    |> Ecto.Changeset.validate_required([:creator_key])
    |> validate_content_size()
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
end
