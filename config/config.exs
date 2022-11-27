import Config

#### Email configuration

# You will almost certainly want to change at least some of these

# include Phoenix web server boilerplate
# import_config "bonfire_web_phoenix.exs"

# include all used Bonfire extensions
import_config "bonfire_encrypt.exs"

config :bonfire_common,
  otp_app: :bonfire

config :bonfire,
  otp_app: :bonfire,
  default_layout_module: Bonfire.UI.Common.LayoutView,
  localisation_path: "priv/localisation"

hasher = if config_env() in [:dev, :test], do: Pbkdf2, else: Argon2

config :bonfire_data_identity, Bonfire.Data.Identity.Credential, hasher_module: hasher

#### Basic configuration

# You probably won't want to touch these. You might override some in
# other config files.

config :bonfire, :repo_module, Bonfire.Common.Repo

config :phoenix, :json_library, Jason

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :mime, :types, %{
  "application/activity+json" => ["activity+json"]
}

# import_config "#{Mix.env()}.exs"
