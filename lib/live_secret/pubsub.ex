defmodule Bonfire.Encrypt.PubSub do
  alias Bonfire.Encrypt.Secret

  @pubsub Bonfire.Common.PubSub

  @doc """
  Subscribe to secret
  """
  def subscribe!(id) do
    :ok = Phoenix.PubSub.subscribe(@pubsub, Secret.topic(id))
  end

  @doc """
  Notifies PubSubtopic for the secret that it has been expired. All listeners should update
  their state for this secret.
  """
  def notify_expired(id) do
    Phoenix.PubSub.broadcast(@pubsub, Secret.topic(id), :expired)
  end
end
