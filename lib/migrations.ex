defmodule Bonfire.Encrypt.Migrations do
  @moduledoc false
  use Ecto.Migration
  import Needle.Migration
  # alias Bonfire.Encrypt.Secret

  # create_secret_table/{0,1}

  defp make_secret_table(exprs) do
    quote do
      require Needle.Migration

      Needle.Migration.create_mixin_table Bonfire.Encrypt.Secret do
        add(:creator_key, :string)
        add(:content, :binary)
        add(:iv, :binary)
        add(:expires_at, :naive_datetime)

        unquote_splicing(exprs)
      end
    end
  end

  defmacro create_secret_table(),
    do: make_secret_table([])

  defmacro create_secret_table(do: {_, _, body}),
    do: make_secret_table(body)

  # drop_secret_table/0

  # `Bonfire.Encrypt.Secret` is what `create_secret_table/0` above makes, so it's what the rollback has to drop. This said `AuthSecondFactor` (unqualified, and from another extension entirely), which never surfaced because nothing had ever run this migration's `down`.
  def drop_secret_table(), do: drop_mixin_table(Bonfire.Encrypt.Secret)

  # migrate_secret/{0,1}

  defp mn(:up), do: make_secret_table([])

  defp mn(:down) do
    quote do
      # `Bonfire.Encrypt.Secret.Migration` does not exist — `drop_secret_table/0` lives here
      Bonfire.Encrypt.Migrations.drop_secret_table()
    end
  end

  defmacro migrate_secret() do
    quote do
      if Ecto.Migration.direction() == :up,
        do: unquote(mn(:up)),
        else: unquote(mn(:down))
    end
  end

  defmacro migrate_secret(dir), do: mn(dir)
end
