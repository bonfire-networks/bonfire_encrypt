defmodule Bonfire.Encrypt.Web.SecretFormLive do
  use Phoenix.Component
  import Phoenix.HTML.Form
  alias Phoenix.LiveView.JS
  import Bonfire.UI.Common.CoreComponents

  def create(assigns) do
    ~H"""
    <%!--
      WARNING: This form is intentionally crippled to prevent any browser or JS submission of plaintext.
      All submission is handled by the EncryptSecret hook via pushEvent.
    --%>
    <.form
      :let={f}
      id="secret-form"
      for={@changeset}
      action="javascript:void(0);"
      method="post"
      class="relative"
      id="secret-form"
      autocomplete="off"
      novalidate
      phx-hook="EncryptSecret"
      data-encrypt-fields="content"
      data-group="default-group"
      data-forward-event="create"
    >
      <%!-- WARNING: make sure to not directly call LiveView events which may send secret data to the server! Let EncryptSecret take care of that. 
      phx-change="validate"
      phx-submit="create" --%>
      <div class="overflow-hidden rounded-lg border shadow-sm  focus-within:ring-1 ">
        <.label field={f[:content]} class="block text-xs font-medium  pt-2 px-2">
          Write your secret
        </.label>
        <div phx-update="ignore" id="cleartext-div-for-ignore">
          <textarea
            id="cleartext"
            name="content"
            class="h-24 sm:h-64 pt-3 block w-full resize-y border-0 py-0 placeholder-gray-500 focus:ring-0 font-mono"
            placeholder="Put your secret information here..."
          />
        </div>
        <.input type="hidden" field={f[:content]} id="ciphertext" />
        <!-- Spacer element to match the height of the toolbar -->
        <.spacer />
      </div>

      <div class="absolute inset-x-px bottom-0">
        <div class="flex items-center justify-between space-x-3 border-t border-gray-200 px-2 py-2 sm:px-3">
          <.create_button />
        </div>
      </div>
    </.form>
    """
  end

  def toolbar_icon(assigns) do
    ~H"""
    <%= case @id do %>
      <% :calendar -> %>
        <svg
          class="h-5 w-5 flex-shrink-0 text-gray-300 sm:-ml-1"
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 20 20"
          fill="currentColor"
          aria-hidden="true"
        >
          <path
            fill-rule="evenodd"
            d="M5.75 2a.75.75 0 01.75.75V4h7V2.75a.75.75 0 011.5 0V4h.25A2.75 2.75 0 0118 6.75v8.5A2.75 2.75 0 0115.25 18H4.75A2.75 2.75 0 012 15.25v-8.5A2.75 2.75 0 014.75 4H5V2.75A.75.75 0 015.75 2zm-1 5.5c-.69 0-1.25.56-1.25 1.25v6.5c0 .69.56 1.25 1.25 1.25h10.5c.69 0 1.25-.56 1.25-1.25v-6.5c0-.69-.56-1.25-1.25-1.25H4.75z"
            clip-rule="evenodd"
          />
        </svg>
      <% :lock -> %>
        <svg
          class="h-5 w-5 flex-shrink-0 text-gray-300 sm:-ml-1"
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 20 20"
          fill="currentColor"
          aria-hidden="true"
        >
          <path
            fill-rule="evenodd"
            d="M10 1a4.5 4.5 0 00-4.5 4.5V9H5a2 2 0 00-2 2v6a2 2 0 002 2h10a2 2 0 002-2v-6a2 2 0 00-2-2h-.5V5.5A4.5 4.5 0 0010 1zm3 8V5.5a3 3 0 10-6 0V9h6z"
            clip-rule="evenodd"
          />
        </svg>
      <% :unlock -> %>
        <svg
          class="h-5 w-5 flex-shrink-0 text-gray-300 sm:-ml-1"
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 20 20"
          fill="currentColor"
          aria-hidden="true"
        >
          <path
            fill-rule="evenodd"
            d="M14.5 1A4.5 4.5 0 0010 5.5V9H3a2 2 0 00-2 2v6a2 2 0 002 2h10a2 2 0 002-2v-6a2 2 0 00-2-2h-1.5V5.5a3 3 0 116 0v2.75a.75.75 0 001.5 0V5.5A4.5 4.5 0 0014.5 1z"
            clip-rule="evenodd"
          />
        </svg>
      <% map when is_map(map) -> %>
        <.toolbar_icon id={map[@choice]} choice={@choice} />
    <% end %>
    """
  end

  def spacer(assigns) do
    ~H"""
    <div aria-hidden="true">
      <div class="py-2">
        <div class="h-9"></div>
      </div>
      <div class="h-px"></div>
      <div class="py-2">
        <div class="py-px">
          <div class="h-9"></div>
        </div>
      </div>
    </div>
    """
  end

  # passphrase_entry removed for OpenMLS

  def create_button(assigns) do
    ~H"""
    <div class="flex-shrink-0">
      <button
        type="submit"
        class="inline-flex items-center rounded-md border border-transparent px-4 py-2 text-sm font-medium shadow-sm  focus:outline-none focus:ring-2  focus:ring-offset-2"
      >
        Encrypt
      </button>
    </div>
    """
  end

  def choice_text(assigns) do
    ~H"""
    <%= case @v do %>
      <% "1h" -> %>
        1 hour
      <% "1d" -> %>
        1 day
      <% "3d" -> %>
        3 days
      <% "1w" -> %>
        1 week
      <% _ -> %>
        error
    <% end %>
    """
  end
end
