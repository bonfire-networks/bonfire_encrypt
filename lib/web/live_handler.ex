defmodule Bonfire.Encrypt.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler

  # alias Phoenix.LiveView.JS
  # alias Bonfire.Encrypt.Web.{SecretFormComponent, ActiveUser}
  alias Bonfire.Encrypt.{Presecret, Secret}

  require Logger

  @impl true

  # Validates form data during secret creation
  def handle_event(
        "validate",
        %{"presecret" => attrs},
        socket = %{assigns: %{changeset: _changeset}}
      ) do
    changeset = Presecret.validate_presecret(attrs)
    {:noreply, assign(socket, changeset: changeset)}
  end

  # Submit form data for secret creation
  def handle_event("create", %{"presecret" => attrs}, socket) do
    secret = %Secret{id: id, creator_key: creator_key} = Bonfire.Encrypt.Secret.insert!(attrs)

    {:noreply,
     socket
     |> assign_secret_metadata(secret)
     |> assign(changeset: nil)
     |> assign(page_title: "Managing Secret")
     |> push_patch(to: Routes.page_path(socket, :admin, id, %{key: creator_key}))}
  end

  # Unlock a specific user for content decryption
  def handle_event(
        "unlock",
        %{"id" => user_id},
        socket = %{assigns: %{live_action: :admin, id: id}}
      ) do
    # presence meta must be updated from the "owner" process so we have to broadcast first
    # so that we can select the right user
    Bonfire.Encrypt.PubSub.notify_unlocked!(id, user_id)
    {:noreply, socket}
  end

  # Burn the secret so that no one else can access it
  def handle_event(
        "burn",
        params,
        socket = %{
          assigns: %{id: id, current_user: current_user, live_action: live_action} = _assigns
        }
      ) do
    secret = Bonfire.Encrypt.Secret.get_secret!(id)

    # if assert_burnkey_match(params, secret) and
    #      live_action === :receiver do
    #   Bonfire.Encrypt.Web.Presence.on_revealed(id, assigns[:users][current_user.id])
    # end

    if assert_burnable(live_action, params, secret) do
      secret = Bonfire.Encrypt.Secret.burn!(secret, burned_by: current_user.id)

      {:noreply,
       socket
       |> assign_secret_metadata(secret)
       |> put_burn_flash()}
    else
      {:noreply, socket}
    end
  end

  def assign_secret_metadata(socket, %Secret{
        id: id,
        creator_key: creator_key,
        burned_at: burned_at
      }) do
    socket
    |> assign(
      id: id,
      creator_key: creator_key,
      burned_at: burned_at
    )
  end

  def assert_creator_key!(socket, id, key) do
    result = Bonfire.Encrypt.Secret.get_secret!(id)
    ^key = result.creator_key
    socket
  end

  def assert_burnkey_match(params, secret) do
    burn_key = params["secret"]["burn_key"]

    case secret.burn_key do
      ^burn_key ->
        true

      _ ->
        false
    end
  end

  def assert_burnable(live_action, params, secret) do
    case live_action do
      :admin ->
        true

      _ ->
        assert_burnkey_match(params, secret)
    end
  end

  def put_burn_flash(socket = %{assigns: %{live_action: :admin}}) do
    socket
    |> put_flash(
      :info,
      "Burned. Encrypted content deleted from server. Close this window."
    )
  end

  def put_burn_flash(socket = %{assigns: %{live_action: :receiver}}) do
    socket
    |> put_flash(
      :info,
      "The secret content has been deleted from the server. Please close this window."
    )
  end
end
