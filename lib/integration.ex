defmodule Bonfire.Encrypt do
  @moduledoc "./README.md" |> File.stream!() |> Enum.drop(1) |> Enum.join()

  use Bonfire.Common.Config
  use Bonfire.Common.Localise
  use Bonfire.Common.Repo
  use Bonfire.Common.E
  alias Bonfire.Common.Text
  alias Bonfire.Common.Types
  import Untangle

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
    object_type = if verb == :create, do: "PrivateMessage", else: "TODO"

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
  def ap_receive_activity(
        creator,
        %{data: activity_data} = ap_activity,
        %{data: %{"type" => type} = object_data} = ap_object
      )
      when type in ["PrivateMessage", "PublicMessage"] do
    # id = e(ap_object, :pointer_id, nil) || e(ap_object, :pointer, :id, nil)

    # reply_to_ap_object = Threads.reply_to_ap_object(activity_data, object_data)
    # reply_to_id = e(reply_to_ap_object, :pointer_id, nil)

    direct_recipients =
      Bonfire.Federate.ActivityPub.AdapterUtils.all_known_recipient_characters(
        activity_data,
        object_data
      )
      |> debug("direct_recipients")

    attrs = %{
      to_circles: direct_recipients,
      post_content: %{
        name: object_data["name"],
        summary: object_data["summary"],
        html_body: object_data["content"]
      },
      replied:
        %{
          # thread_id: activity.data["context"], 
          # reply_to_id: reply_to_id
        }
    }

    Bonfire.Messages.send(creator, attrs)
  end
end
