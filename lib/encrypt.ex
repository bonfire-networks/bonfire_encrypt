defmodule Bonfire.Encrypt do
  @moduledoc "./README.md" |> File.stream!() |> Enum.drop(1) |> Enum.join()

  use Bonfire.Common.Config
  use Bonfire.Common.Localise
  use Bonfire.Common.Repo
  use Bonfire.Common.E
  alias Bonfire.Common.Text
  alias Bonfire.Common.Types
  import Untangle
  import ActivityPub.Config, only: [is_in: 2]

  @doc """
  Clears all key packages for a local actor by removing every member from their `keyPackages`
  collection, federating a `Remove` for each (MLS-over-ActivityPub lifecycle).

  By default also federates a `Delete` for each key package object so it becomes unavailable; pass
  `delete: false` to only `Remove` them from the collection without deleting the objects.
  """
  def clear_key_packages(user_or_id, opts \\ [])

  def clear_key_packages(%Bonfire.Data.Identity.User{} = user, opts) do
    with {:ok, actor} <- ActivityPub.Actor.get_cached(pointer: user.id),
         {:ok, collection} <-
           ActivityPub.GenericCollectionStore.get_or_create_collection(
             "keyPackages",
             user.id,
             actor.ap_id
           ) do
      delete? = Keyword.get(opts, :delete, true)

      for ap_id <- ActivityPub.GenericCollectionStore.member_ap_ids(collection) do
        # `remove` federates the Remove to followers and drops the membership
        ActivityPub.remove(%{
          actor: actor,
          object: ap_id,
          target: collection.data["id"],
          local: true
        })

        if delete?, do: maybe_delete_key_package(ap_id)
      end

      {:ok, collection}
    end
  end

  def clear_key_packages(actor_or_id, opts) do
    with {:ok, user} <- Bonfire.Me.Users.by_username(actor_or_id) do
      clear_key_packages(user, opts)
    else
      _ ->
        with {:ok, actor} <- ActivityPub.Actor.get_cached(ap_id: Types.uid(actor_or_id)),
             %{pointer: %Bonfire.Data.Identity.User{} = user} <- actor do
          clear_key_packages(user, opts)
        end
    end
  end

  defp maybe_delete_key_package(ap_id) do
    case ActivityPub.Object.get_cached(ap_id: ap_id) do
      {:ok, object} -> ActivityPub.delete(object, true)
      _ -> :ok
    end
  end

  @behaviour Bonfire.Federate.ActivityPub.FederationModules
  def federation_module,
    do: [
      "PublicMessage",
      "PrivateMessage"
      # "Welcome", "GroupInfo", "KeyPackage"
    ]

  @doc """
  Publishes an activity to the ActivityPub.

  ## Examples

      iex> Bonfire.Messages.ap_publish_activity(subject, verb, message)
  """
  def ap_publish_activity(subject, verb, message) do
    message =
      message
      |> repo().maybe_preload([
        :post_content,
        :created,
        # :sensitive,
        # recipients
        :tags,
        replied: [
          # thread: [:created], reply_to: [:created]
        ]
      ])
      # |> Activities.object_preload_create_activity()
      |> debug("message to federate")

    %{actor: actor, context: context, to: to, reply_to: reply_to, recipients: recipients} =
      Bonfire.Messages.ap_publish_prepare_metadata(subject, verb, message)

    # TODO: determine object type
    object_type = if verb == :create, do: "PrivateMessage", else: err("TODO")

    object =
      if object_type == "PrivateMessage" do
        %{
          # "name" => nil,
          "summary" =>
            l(
              "This is an encrypted message. Please read it using a compatible app (supporting MLS end-to-end encryption)."
            ),
          "content" => e(message, :post_content, :html_body, nil)
        }
      else
        %{
          "name" => e(message, :post_content, :name, nil),
          "summary" => e(message, :post_content, :summary, nil),
          "content" => Text.maybe_markdown_to_html(e(message, :post_content, :html_body, nil)),
          "inReplyTo" => reply_to
        }
      end

    object =
      Map.merge(object, %{
        "type" => object_type,
        "actor" => actor.ap_id,
        "to" => to,
        "context" => context,
        # TODO: do we need to include mentions for recipients?
        "tag" =>
          Enum.map(recipients, fn actor ->
            %{
              "href" => actor.ap_id,
              "name" => actor.username,
              "type" => "Mention"
            }
          end)
      })

    params = %{
      actor: actor,
      context: context,
      object: object,
      to: to,
      pointer: Types.uid(message)
    }

    if verb == :edit, do: ActivityPub.update(params), else: ActivityPub.create(params)
  end

  @doc """
  Receives an activity from ActivityPub.

  ## Examples

      iex> Bonfire.Messages.ap_receive_activity(creator, activity, object)
  """

  # receipts are stored and federated by the AP layer; no Bonfire object needed
  def ap_receive_activity(
        _creator,
        ap_activity,
        %{data: %{"type" => type} = object_data} = _ap_object
      )
      when is_in(type, ["Acknowledge", "Failure"]) do
    # C2S skips auto-federation, so trigger it manually for local activities
    if Map.get(ap_activity, :local), do: ActivityPub.Federator.publish(ap_activity)

    # Notify local recipients (the original message sender) via PubSub so SSE clients update delivery status
    thread_id = object_data["context"] || e(ap_activity, :data, "context", nil)

    Bonfire.Federate.ActivityPub.AdapterUtils.all_activity_recipients(
      e(ap_activity, :data, %{}),
      object_data
    )
    |> Bonfire.Federate.ActivityPub.AdapterUtils.local_actor_ids()
    |> Enum.each(fn {_ap_id, user} ->
      if inbox_feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, user),
        do:
          Bonfire.Common.PubSub.broadcast(inbox_feed_id, {:new_message, %{thread_id: thread_id}})
    end)

    {:ok, :skipped}
  end

  def ap_receive_activity(
        creator,
        %{data: activity_data} = ap_activity,
        %{data: %{"type" => type} = object_data} = ap_object
      )
      when is_in(type, ["PrivateMessage", "PublicMessage"]) do
    pointer_id = Map.get(ap_object, :pointer_id) || e(ap_object, :pointer, :id, nil)

    # reply_to_ap_object = Threads.reply_to_ap_object(activity_data, object_data)
    # reply_to_id = e(reply_to_ap_object, :pointer_id, nil)

    direct_recipients =
      Bonfire.Federate.ActivityPub.AdapterUtils.all_known_recipient_characters(
        activity_data,
        object_data
      )
      |> debug("direct_recipients")

    attrs = %{
      id: pointer_id,
      to_circles: direct_recipients,
      post_content: %{
        name: object_data["name"],
        summary: object_data["summary"],
        html_body: object_data["content"]
      }
      # replied:
      #   %{
      #     # thread_id: activity.data["context"],
      #     # reply_to_id: reply_to_id
      #   }
    }

    # For local C2S: pass the original AP activity so Outgoing can federate it directly
    opts =
      if Map.get(ap_activity, :local),
        do: [current_user: creator, from_c2s_activity: ap_activity],
        else: creator

    Bonfire.Messages.send(opts, attrs)
  end
end
