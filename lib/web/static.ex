defmodule Bonfire.Encrypt.Web.Static do
  use Plug.Builder

  plug :send_file

  def send_file(conn, _opts) do
    priv_dir = :code.priv_dir(:bonfire_encrypt)
    file_path = Path.join([priv_dir, "static", "eff_large_wordlist.json"])

    send_file(conn, 200, file_path)
  end
end
