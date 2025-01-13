defmodule Bonfire.Encrypt.Web.Routes do
  @behaviour Bonfire.UI.Common.RoutesModule

  defmacro __using__(_) do
    quote do
      # serve static file
      scope "/encrypt/static/", Bonfire.Encrypt.Web do
        pipe_through(:browser)

        forward("/eff_large_wordlist.json", Static)
      end

      # pages anyone can view
      scope "/encrypt", Bonfire.Encrypt.Web do
        pipe_through(:browser)
      end

      # pages only guests can view
      scope "/", Bonfire.Encrypt.Web do
        pipe_through(:browser)
        pipe_through(:guest_only)
      end

      scope "/", Bonfire do
        pipe_through(:browser)
        pipe_through(:account_required)
      end

      # pages you need an account to view
      scope "/", Bonfire.Encrypt.Web do
        pipe_through(:browser)
        pipe_through(:account_required)
      end

      # pages you need to view as a user
      scope "/encrypt", Bonfire.Encrypt.Web do
        pipe_through(:browser)
        pipe_through(:user_required)

        live("/", PageLive, :create)
        live("/admin/:id", PageLive, :admin)
        live("/secret/:id", PageLive, :receiver)
      end

      # pages only admins can view
      scope "/settings", Bonfire.Encrypt.Web do
        pipe_through(:browser)
        pipe_through(:admin_required)
      end
    end
  end
end
