defmodule Bonfire.Encrypt.Web.PageLive do
  use Bonfire.UI.Common.Web, :live_view
  alias Bonfire.UI.Me.LivePlugs

  alias Phoenix.LiveView.JS
  alias Bonfire.Encrypt.{Presecret, Secret}
  alias Bonfire.Encrypt.LiveHandler
  alias Bonfire.Encrypt.Web.SecretFormLive

  require Logger

  def mount(params, session, socket) do
    live_plug(params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
      &mounted/3
    ])
  end

  @impl true
  defp mounted(%{"id" => id, "key" => key}, %{}, socket = %{assigns: %{live_action: :admin}}) do
    case read_secret_or_redirect(socket, id) do
      secret = %Secret{} ->
        {
          :ok,
          socket
          |> assign(page_title: "Managing Secret")
          |> LiveHandler.assert_creator_key!(id, key)
          |> LiveHandler.assign_secret_metadata(secret)
          |> assign(special_action: nil)
          #  |> detect_presence()
        }

      socket ->
        {:ok, socket}
    end
  end

  defp mounted(%{"id" => id}, %{}, socket = %{assigns: %{live_action: :receiver}}) do
    case read_secret_or_redirect(socket, id) do
      secret = %Secret{} ->
        {
          :ok,
          socket
          |> assign(page_title: "Receiving Secret")
          |> LiveHandler.assign_secret_metadata(secret)
          |> assign(special_action: :decrypting)
          #  |> detect_presence()
        }

      socket ->
        {:ok, socket}
    end
  end

  defp mounted(_params, %{}, socket = %{assigns: %{live_action: :create}}) do
    {:ok,
     socket
     |> assign(page_title: "Live Secret")
     |> LiveHandler.assign_secret_metadata(%Secret{})
     |> assign(special_action: nil)
     |> assign(changeset: Presecret.changeset(Presecret.new(), %{}))}
  end

  @impl true
  # Handle the push_patch after secret creation. We use a patch so that the DOM doesn't get
  # reset. This allows the client browser to hold onto the passphrase so the instructions
  # can be generated.
  def handle_params(
        %{"id" => id, "key" => key},
        _url,
        socket = %{assigns: %{live_action: :admin}}
      ) do
    case read_secret_or_redirect(socket, id) do
      secret = %Secret{} ->
        {
          :noreply,
          socket
          |> LiveHandler.assert_creator_key!(id, key)
          |> LiveHandler.assign_secret_metadata(secret)
          #  |> detect_presence()
        }

      socket ->
        {:noreply, socket}
    end
  end

  def handle_params(_, _, socket) do
    {:noreply, socket}
  end

  @impl true
  # Handles presence -- users coming online and offline from the page
  # def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
  #   {
  #     :noreply,
  #     socket
  #     |> handle_leaves(diff.leaves)
  #     |> handle_joins(diff.joins)
  #   }
  # end

  # Broadcast to all listeners when a user is unlocked. However, only the specific user
  # should do anything with it.
  def handle_info(
        {:unlocked, user_id},
        socket = %{assigns: %{current_user: current_user, id: id, users: users}}
      ) do
    case current_user.id do
      ^user_id ->
        if Bonfire.Encrypt.Web.Presence.on_unlocked(id, users[user_id]) do
          {:noreply,
           socket
           |> assign(special_action: :decrypting)}
        else
          {:noreply, socket}
        end

      _ ->
        {:noreply, socket}
    end
  end

  # All subscribers are informed the secret has been burned
  def handle_info(
        {:burned, burned_at, burned_by: burned_by},
        socket = %{assigns: %{current_user: current_user}}
      ) do
    case current_user.id do
      ^burned_by ->
        {:noreply, socket}

      _ ->
        {:noreply,
         socket
         |> assign(burned_at: burned_at)
         |> LiveHandler.put_burn_flash()}
    end
  end

  # All subscribers are informed the secret has been expired
  def handle_info(:expired, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "The secret has expired. You've been redirected to the home page.")
     |> push_navigate(to: Routes.page_path(socket, :create))}
  end

  defdelegate handle_event(a, b, c), to: LiveHandler

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-full">
      <div class="pb-32">
        <header class="py-10">
          <div class="px-4 mx-auto max-w-7xl sm:px-6 lg:px-8">
            <h1 class="text-3xl font-bold tracking-tight">Live Secret</h1>
          </div>
        </header>
      </div>

      <main class="-mt-32">
        <div class="px-4 pb-12 mx-auto max-w-7xl sm:px-6 lg:px-8">
          <div class="px-5 py-6 rounded-lg shadow sm:px-6">
            <%= case @special_action do %>
              <% :decrypting -> %>
                <% secret = Bonfire.Encrypt.Secret.get_secret!(@id) %>
                <.decrypt_modal
                  :if={not is_nil(secret.content)}
                  secret={secret}
                  changeset={Secret.changeset(secret, %{})}
                />
              <% _ -> %>
            <% end %>

            <%= case @live_action do %>
              <% :create -> %>
                <.secret_links
                  live_action={@live_action}
                  to={Routes.page_path(@socket, :receiver, "dne")}
                  enabled={is_nil(@burned_at)}
                />
                <SecretFormLive.create
                  changeset={@changeset}
                  durations={Presecret.supported_durations()}
                />
              <% :admin -> %>
                <.secret_links
                  live_action={@live_action}
                  to={Routes.page_path(@socket, :receiver, @id)}
                  enabled={is_nil(@burned_at)}
                />

                <.section_header>Actions</.section_header>
                <.action_panel burned_at={@burned_at} />
              <% :receiver -> %>
             

            <% end %>
          </div>
        </div>
      </main>
    </div>
    """
  end

  # Rendered for live_action = :create | :admin so that the passphrase can be held in the DOM
  defp secret_links(assigns) do
    ~H"""
    <% container_class = if @live_action == :create, do: "", else: "pt-8 px-8 pb-2" %>
    <div class={container_class}>
      <ul>
        <%= if @live_action == :admin do %>
          <% oob_url = build_external_url(@to) %>

          <div class="flex items-center justify-center w-full align-center">
            <button
              type="button"
              class={" inline-flex items-center justify-center rounded-md border border-transparent px-4 py-2 font-medium focus:outline-none focus:ring-2 focus:ring-offset-2 sm:text-sm "<> if @enabled, do: "", else: "line-through"}
              phx-click={JS.dispatch("live-secret:clipcopy-instructions")}
              disabled={not @enabled}
            >
              Copy as Markdown <.action_icon has_text={true} id={:markdown} />
            </button>
            <div :if={@enabled} id="show-passphrase-after-create" phx-hook="ShowPassphraseAfterCreate">
            </div>
          </div>
          <.copiable
            id="oob-url"
            type={:text}
            value={oob_url}
            ignore={false}
            enabled={@enabled}
            placeholder=""
          />
        <% end %>

        <% input_type = if @live_action == :create, do: :hidden, else: :text %>
        <.copiable
          id="userkey-stash"
          type={input_type}
          value=""
          ignore={true}
          enabled={@enabled}
          placeholder="<Admin must provide the passphrase>"
        />
      </ul>
    </div>
    """
  end

  defp copiable(assigns) do
    ~H"""
    <li class="flex my-2 flex-nowrap">
      <button
        :if={@type != :hidden}
        type="button"
        disabled={not @enabled}
        class="inline-flex items-center px-3 border border-r-0 rounded-l-md sm:text-sm"
        phx-click={if @enabled, do: JS.dispatch("live-secret:clipcopy", to: "##{@id}")}
      >
        <.action_icon has_text={false} id={:clipboard} />
      </button>

      <% input_class =
        "font-mono block w-full min-w-0 flex-1 rounded-none rounded-r-md  px-3 py-2 sm:text-sm " %>

      <%= if @ignore do %>
        <div phx-update="ignore" id={@id <> "-div-for-ignore"} class="w-full">
          <input
            type={@type}
            id={@id}
            disabled
            class={input_class}
            value={@value}
            placeholder={@placeholder}
          />
        </div>
      <% else %>
        <input
          type={@type}
          id={@id}
          disabled
          class={input_class}
          value={@value}
          placeholder={@placeholder}
        />
      <% end %>
    </li>
    """
  end

  defp decrypt_modal(assigns) do
    ~H"""
    <div
      id="decrypt-modal"
      class="relative z-10"
      aria-labelledby="modal-title"
      role="dialog"
      aria-modal="true"
    >
      <!--
      Background backdrop, show/hide based on modal state.

      Entering: "ease-out duration-300"
        From: "opacity-0"
        To: "opacity-100"
      Leaving: "ease-in duration-200"
        From: "opacity-100"
        To: "opacity-0"
    -->
      <div class="fixed inset-0 transition-opacity bg-opacity-75"></div>

      <div class="fixed inset-0 z-10 overflow-y-auto">
        <div class="flex items-end justify-center min-h-full p-4 text-center sm:items-center">
          <!--
          Modal panel, show/hide based on modal state.

          Entering: "ease-out duration-300"
            From: "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"
            To: "opacity-100 translate-y-0 sm:scale-100"
          Leaving: "ease-in duration-200"
            From: "opacity-100 translate-y-0 sm:scale-100"
            To: "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"
        -->
          <div class="relative px-4 pt-5 pb-4 overflow-hidden text-left transition-all transform rounded-lg shadow-xl sm:my-8 sm:w-full md:w-2/3 sm:p-6">
            <div>
              <div class="flex items-center justify-center w-12 h-12 mx-auto bg-red-100 rounded-full">
                <!-- Heroicon name: outline/lock-open -->
                <svg
                  class="w-6 h-6 text-red-600"
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  aria-hidden="true"
                >
                  <path d="M18 1.5c2.9 0 5.25 2.35 5.25 5.25v3.75a.75.75 0 01-1.5 0V6.75a3.75 3.75 0 10-7.5 0v3a3 3 0 013 3v6.75a3 3 0 01-3 3H3.75a3 3 0 01-3-3v-6.75a3 3 0 013-3h9v-3c0-2.9 2.35-5.25 5.25-5.25z" />
                </svg>
              </div>
              <div class="mt-3 text-center sm:mt-5">
                <h3 class="text-lg font-medium leading-6 " id="modal-title">
                  Enter the passphrase
                </h3>
                <div class="mt-2">
                  <p class="text-sm ">
                    Paste the passphrase into this box and click 'Decrypt'. The secret content will be shown if the passphrase is correct.
                  </p>
                </div>
                <div class="pt-2" phx-update="ignore" id="passphrase-div-for-ignore">
                  <input
                    type="text"
                    name="passphrase"
                    id="passphrase"
                    class="block w-full px-4 rounded-full shadow-sm sm:text-sm"
                    placeholder="Passphrase"
                    autocomplete="off"
                  />
                </div>
              </div>
            </div>

            <div id="ciphertext-div-for-ignore" phx-update="ignore">
              <input
                type="hidden"
                id="ciphertext"
                value={if is_nil(@secret.content), do: nil, else: :base64.encode(@secret.content)}
              />
            </div>
            <div id="iv-div-for-ignore" phx-update="ignore">
              <input
                type="hidden"
                id="iv"
                value={if is_nil(@secret.iv), do: nil, else: :base64.encode(@secret.iv)}
              />
            </div>
            <div id="decryptionfailure-div-for-ignore" phx-update="ignore">
              <div id="decryptionfailure-container" class="hidden pt-1 text-center">
                <div class="inline-flex">
                  <div class="block pr-2">
                    <p class="text-md ">Incorrect passphrase - try again</p>
                  </div>
                  <span
                    class="hidden inline-flex items-center rounded-full bg-red-100 px-2.5 py-0.5 text-xs font-medium text-red-800"
                    id="fail-counter"
                  >
                    0
                  </span>
                </div>
              </div>
            </div>
            <div id="cleartext-div-for-ignore" phx-update="ignore">
              <div id="cleartext-container" class="hidden text-center">
                <textarea
                  id="cleartext"
                  readonly
                  class="block w-full font-mono rounded-md resize-none ring-0"
                />
                <div class="flex items-center justify-center w-full p-4 align-center">
                  <button
                    type="button"
                    class="inline-flex items-center justify-center px-4 py-2 font-medium border border-transparent rounded-md focus:outline-none focus:ring-2 focus:ring-offset-2 sm:text-sm "
                    phx-click={JS.dispatch("live-secret:clipcopy", to: "#cleartext")}
                  >
                    Copy to clipboard <.action_icon has_text={true} id={:clipboard} />
                  </button>
                </div>
                <div class="block">
                  <p class="text-md ">Success!</p>
                  <p class="text-sm ">
                    When you leave this window, the content is gone forever.
                  </p>
                </div>
              </div>
            </div>

            <.form :let={f} for={@changeset} phx-change="burn" autocomplete="off">
              <%= hidden_input(f, :burn_key, id: "burnkey") %>
            </.form>

            <div
              id="decrypt-btns-div-for-ignore"
              phx-update="ignore"
              class="mt-5 sm:mt-6 sm:grid sm:grid-flow-row-dense sm:grid-cols-2 sm:gap-3"
            >
              <button
                type="button"
                id="decrypt-btn"
                class="inline-flex w-full btn btn-success sm:col-start-2"
                phx-click={JS.dispatch("live-secret:decrypt-secret")}
              >
                Decrypt
              </button>
              <button
                type="button"
                id="close-btn"
                class="inline-flex w-full btn btn-warning"
                phx-click={JS.hide(to: "#decrypt-modal")}
              >
                Close
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp action_panel(assigns) do
    ~H"""
    <div class="py-4">
      <ul
        role="list"
        class="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-2 lg:grid-cols-2 xl:grid-cols-2 2xl:grid-cols-2"
      >
        <.action_item
          title="Burn this secret"
          description="When you burn the secret, the encrypted data is deleted forever."
          action_enabled={is_nil(@burned_at)}
          action_text="Burn"
          action_icon={:fire}
          action_class="text-red-700 bg-red-100 hover:bg-red-200 focus:ring-red-500"
          action_click="burn"
        >
        </.action_item>
      </ul>
    </div>
    """
  end

  defp action_item(assigns) do
    ~H"""
    <li class="col-span-1 rounded-lg shadow">
      <div class="flex items-center justify-between w-full p-6 space-x-6">
        <div class="flex-1">
          <div class="flex items-center space-x-3">
            <h3 class="text-sm font-medium truncate "><%= @title %></h3>
          </div>
          <p class="mt-1 text-sm "><%= @description %></p>
        </div>
      </div>
      <div class="inline-flex items-center justify-center w-full pb-4">
        <button
          type="button"
          class={"#{@action_class} inline-flex items-center justify-center rounded-md border border-transparent px-4 py-2 font-medium focus:outline-none focus:ring-2 focus:ring-offset-2 sm:text-sm "<> if @action_enabled, do: "", else: "line-through"}
          phx-click={if @action_enabled, do: @action_click}
          disabled={not @action_enabled}
        >
          <%= @action_text %>
          <.action_icon :if={not is_nil(@action_icon)} has_text={true} id={@action_icon} />
        </button>
      </div>
    </li>
    """
  end

  defp action_icon(assigns) do
    ~H"""
    <% margin_for_left_text = if @has_text, do: "ml-2", else: "-ml-1" %>
    <%= case @id do %>
      <% :fire -> %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 20 20"
          fill="currentColor"
          class={margin_for_left_text<>" -mr-1 w-5 h-5"}
        >
          <path
            fill-rule="evenodd"
            d="M13.5 4.938a7 7 0 11-9.006 1.737c.202-.257.59-.218.793.039.278.352.594.672.943.954.332.269.786-.049.773-.476a5.977 5.977 0 01.572-2.759 6.026 6.026 0 012.486-2.665c.247-.14.55-.016.677.238A6.967 6.967 0 0013.5 4.938zM14 12a4 4 0 01-4 4c-1.913 0-3.52-1.398-3.91-3.182-.093-.429.44-.643.814-.413a4.043 4.043 0 001.601.564c.303.038.531-.24.51-.544a5.975 5.975 0 011.315-4.192.447.447 0 01.431-.16A4.001 4.001 0 0114 12z"
            clip-rule="evenodd"
          />
        </svg>
      <% :clipboard -> %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 20 20"
          fill="currentColor"
          class={margin_for_left_text<>" -mr-1 w-5 h-5"}
        >
          <path
            fill-rule="evenodd"
            d="M10.5 3A1.501 1.501 0 009 4.5h6A1.5 1.5 0 0013.5 3h-3zm-2.693.178A3 3 0 0110.5 1.5h3a3 3 0 012.694 1.678c.497.042.992.092 1.486.15 1.497.173 2.57 1.46 2.57 2.929V19.5a3 3 0 01-3 3H6.75a3 3 0 01-3-3V6.257c0-1.47 1.073-2.756 2.57-2.93.493-.057.989-.107 1.487-.15z"
            clip-rule="evenodd"
          />
        </svg>
      <% :markdown -> %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 208 128"
          fill="currentColor"
          class={margin_for_left_text<>" -mr-1 w-5 h-5"}
        >
          <path
            fill-rule="evenodd"
            d="M30 98V30h20l20 25 20-25h20v68H90V59L70 84 50 59v39zm125 0l-30-33h20V30h20v35h20z"
          />
        </svg>
      <% :locked -> %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 20 20"
          fill="currentColor"
          class={margin_for_left_text<>" -mr-1 w-5 h-5"}
        >
          <path
            fill-rule="evenodd"
            d="M10 1a4.5 4.5 0 00-4.5 4.5V9H5a2 2 0 00-2 2v6a2 2 0 002 2h10a2 2 0 002-2v-6a2 2 0 00-2-2h-.5V5.5A4.5 4.5 0 0010 1zm3 8V5.5a3 3 0 10-6 0V9h6z"
            clip-rule="evenodd"
          />
        </svg>
      <% :unlocked -> %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 20 20"
          fill="currentColor"
          class={margin_for_left_text<>" -mr-1 w-5 h-5"}
        >
          <path
            fill-rule="evenodd"
            d="M14.5 1A4.5 4.5 0 0010 5.5V9H3a2 2 0 00-2 2v6a2 2 0 002 2h10a2 2 0 002-2v-6a2 2 0 00-2-2h-1.5V5.5a3 3 0 116 0v2.75a.75.75 0 001.5 0V5.5A4.5 4.5 0 0014.5 1z"
            clip-rule="evenodd"
          />
        </svg>
    <% end %>
    """
  end

  defp section_header(assigns) do
    ~H"""
    <div class="px-4 pt-4 mx-auto max-w-7xl">
      <h2 class="text-lg font-bold leading-tight tracking-tight ">
        <%= render_slot(@inner_block) %>
      </h2>
    </div>
    """
  end

  defp build_external_url(path) do
    "#{base_url()}#{path}"
  end

  # defp handle_joins(socket, joins) do
  #   Enum.reduce(joins, socket, fn {user_id, %{metas: [active_user = %ActiveUser{} | _]}},
  #                                 socket ->
  #     assign(socket, :users, Map.put(socket.assigns.users, user_id, active_user))
  #   end)
  # end

  # defp handle_leaves(socket, leaves) do
  #   left_at = NaiveDateTime.utc_now()

  #   Enum.reduce(leaves, socket, fn {user_id, _}, socket ->
  #     users = socket.assigns.users

  #     case socket.assigns.users[user_id] do
  #       nil ->
  #         socket

  #       active_user ->
  #         active_user = %ActiveUser{active_user | left_at: left_at}

  #         socket
  #         |> assign(users: Map.put(users, user_id, active_user))
  #     end
  #   end)
  # end

  # def detect_presence(socket = %{assigns: %{presence: _}}) do
  #   socket
  # end

  # def detect_presence(
  #       socket = %{assigns: %{current_user: user, id: id, live_action: live_action, live?: live?}}
  #     )
  #     when not is_nil(user) do
  #   active_user = %ActiveUser{
  #     id: user[:id],
  #     name: user[:name],
  #     live_action: live_action,
  #     joined_at: NaiveDateTime.utc_now(),
  #     state: if(live?, do: :locked, else: :unlocked)
  #   }

  #   special_action =
  #     case {live_action, active_user.state} do
  #       {_, :locked} -> nil
  #       {:admin, _} -> nil
  #       {:receiver, :unlocked} -> :decrypting
  #     end

  #   presence_pid = Bonfire.Encrypt.Web.Presence.track(id, active_user)

  #   socket
  #   |> assign(
  #     users: %{user.id => active_user},
  #     presence: presence_pid,
  #     special_action: special_action
  #   )
  #   |> handle_joins(Bonfire.Encrypt.Web.Presence.list(Secret.topic(id)))
  # end

  # def detect_presence(socket = %{assigns: %{id: id}}) do
  #   topic = Secret.topic(id)

  #   socket
  #   |> assign(users: %{})
  #   |> handle_joins(Bonfire.Encrypt.Web.Presence.list(topic))
  # end

  def read_secret_or_redirect(socket, id) do
    case Bonfire.Encrypt.Secret.get_secret(id) do
      secret = %Secret{} ->
        secret

      error ->
        Logger.info("#{id} not found: #{inspect(error)}")

        socket
        |> put_flash(
          :error,
          "That secret doesn't exist. You've been redirected to the home page."
        )
        |> push_navigate(to: Routes.page_path(socket, :create))
    end
  end
end
