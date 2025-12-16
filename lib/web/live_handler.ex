defmodule Bonfire.Encrypt.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler

  # alias Phoenix.LiveView.JS
  # alias Bonfire.Encrypt.Web.{SecretFormComponent, ActiveUser}
  alias Bonfire.Encrypt.Secret

  require Logger

  # Submit form data for secret creation
  def handle_event("create", attrs, socket) do
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

  def handle_event("clear-flash", _params, socket) do
    {:noreply, clear_flash(socket)}
  end

  # Handle onboarding_status event from client (OpenMLS onboarding feedback)
  def handle_event("onboarding_status", %{"status" => status} = params, socket) do
    socket =
      socket
      |> assign(:onboarding_status, status)
      |> assign(:onboarding_error, Map.get(params, "error"))

    {:noreply, socket}
  end

  # Handle group_status event from client (OpenMLS group feedback)
  def handle_event("group_status", %{"status" => status} = params, socket) do
    socket =
      socket
      |> assign(:group_status, status)
      |> assign(:group_error, Map.get(params, "error"))

    {:noreply, socket}
  end

  @impl true
  def handle_event("set_group", %{"group_id" => group_id}, socket) do
    # Update the group id and reset group status to pending
    {:noreply,
     socket
     |> assign(id: group_id, group_status: :pending, error: nil)}
  end

  @impl true
  def handle_event("copy_invite_link", _params, socket) do
    # Generate a real OpenMLS welcome message for the group (replace with real logic)
    group_id = socket.assigns[:id]
    welcome_message = Base.encode64("welcome-for-" <> (group_id || ""))

    invite_url =
      Routes.page_url(socket, :create) <>
        "?group_id=" <> (group_id || "") <> "&welcome=" <> welcome_message

    {:noreply, assign(socket, invite_link: invite_url)}
  end

  def handle_event("accept_invite", _params, socket) do
    # Accept the invite and join the group using the welcome message
    # Here you would call your OpenMLS backend logic to process the welcome message and add the user to the group
    # For demo, we just mark the group as ready
    # In production, decode and process the welcome message, update group state, etc.
    {:noreply, assign(socket, group_status: :ready, error: nil, welcome_message: nil)}
  end

  def assign_secret_metadata(socket, %Secret{
        id: id,
        creator_key: creator_key
      }) do
    socket
    |> assign(
      id: id,
      creator_key: creator_key
    )
  end

  def assert_creator_key!(socket, id, key) do
    result = Bonfire.Encrypt.Secret.get_secret!(id)
    ^key = result.creator_key
    socket
  end
end
