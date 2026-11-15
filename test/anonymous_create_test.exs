defmodule Bonfire.Encrypt.AnonymousCreateTest do
  @moduledoc """
  Storing a secret is for signed-in users. A visitor without a session who sends `create` through the plain `/LiveHandler` route must not add a secret.
  """

  use Bonfire.Encrypt.ConnCase, async: false

  alias Bonfire.Encrypt.Secret

  test "a secret can be stored (control)" do
    before_count = Secret.count_secrets()

    Secret.insert!(%{id: Bonfire.Me.Fake.fake_user!().id, creator_key: "control-key"})

    assert Secret.count_secrets() == before_count + 1
  end

  test "a visitor without a session cannot store a secret" do
    before_count = Secret.count_secrets()
    id = Bonfire.Me.Fake.fake_user!().id

    # the request may fail while rendering its answer, what matters is whether a secret was stored first
    try do
      get(
        build_conn(),
        "/LiveHandler/Bonfire.Encrypt/create?" <>
          URI.encode_query(%{"id" => id, "creator_key" => "anonymous-key"})
      )
    rescue
      _ -> :ok
    end

    assert Secret.count_secrets() == before_count
  end
end
