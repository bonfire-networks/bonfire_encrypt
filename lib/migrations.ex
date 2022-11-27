defmodule Bonfire.Encrypt.Migrations do
  use Ecto.Migration
  import Pointers.Migration
  alias Bonfire.Encrypt.Secret

  # create_secret_table/{0,1}

  defp make_secret_table(exprs) do
    quote do
      require Pointers.Migration

      Pointers.Migration.create_mixin_table Bonfire.Encrypt.Secret do
        add(:creator_key, :string)
        add(:burn_key, :string)
        add(:content, :binary)
        add(:iv, :binary)
        add(:burned_at, :naive_datetime)
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

  def drop_secret_table(), do: drop_mixin_table(AuthSecondFactor)

  # migrate_secret/{0,1}

  defp mn(:up), do: make_secret_table([])

  defp mn(:down) do
    quote do
      Bonfire.Encrypt.Secret.Migration.drop_secret_table()
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
