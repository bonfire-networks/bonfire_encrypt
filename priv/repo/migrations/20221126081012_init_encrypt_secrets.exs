defmodule Bonfire.Encrypt.Repo.Migrations.InitSecret do
  @moduledoc false
  use Ecto.Migration
  require Bonfire.Encrypt.Migrations

  def up do
    Bonfire.Encrypt.Migrations.migrate_secret()
  end

  def down do
    Bonfire.Encrypt.Migrations.migrate_secret()
  end
end
