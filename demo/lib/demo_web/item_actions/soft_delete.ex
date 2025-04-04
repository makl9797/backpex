defmodule DemoWeb.ItemActions.SoftDelete do
  @moduledoc false

  use BackpexWeb, :item_action

  import Ecto.Changeset
  alias Backpex.ItemActions.Delete
  require Logger

  @impl Backpex.ItemAction
  def icon(assigns) do
    ~H"""
    <Heroicons.trash class="h-5 w-5 cursor-pointer transition duration-75 hover:scale-110 hover:text-red-600" />
    """
  end

  @impl Backpex.ItemAction
  def fields do
    [
      reason: %{
        module: Backpex.Fields.Textarea,
        label: "Reason",
        type: :string
      }
    ]
  end

  @required_fields ~w[reason]a

  @impl Backpex.ItemAction
  def changeset(change, attrs, _metadata) do
    change
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
  end

  @impl Backpex.ItemAction
  def label(assigns), do: Delete.label(assigns)

  @impl Backpex.ItemAction
  def confirm_label(assigns), do: Delete.confirm_label(assigns)

  @impl Backpex.ItemAction
  def cancel_label(assigns), do: Delete.cancel_label(assigns)

  @impl Backpex.ItemAction
  def confirm(assigns) do
    count = Enum.count(assigns.selected_items)

    if count > 1 do
      Backpex.translate({"Why do you want to delete these %{count} items?", %{count: count}})
    else
      Backpex.translate("Why do you want to delete this item?")
    end
  end

  @impl Backpex.ItemAction
  def handle(socket, items, _params) do
    datetime = DateTime.truncate(DateTime.utc_now(), :second)

    socket =
      try do
        {:ok, _items} = Backpex.Resource.update_all(socket.assigns, items, [set: [deleted_at: datetime]], "deleted")

        socket
        |> clear_flash()
        |> put_flash(:info, success_message(socket.assigns, items))
      rescue
        error ->
          Logger.error("An error occurred while deleting the resource: #{inspect(error)}")

          socket
          |> clear_flash()
          |> put_flash(:error, error_message(socket.assigns, error, items))
      end

    {:noreply, socket}
  end

  defp success_message(assigns, [_item]) do
    Backpex.translate({"%{resource} has been deleted successfully.", %{resource: assigns.singular_name}})
  end

  defp success_message(assigns, items) do
    Backpex.translate(
      {"%{count} %{resources} have been deleted successfully.",
       %{resources: assigns.plural_name, count: Enum.count(items)}}
    )
  end

  defp error_message(assigns, %Postgrex.Error{postgres: %{code: :foreign_key_violation}}, [_item] = items) do
    "#{error_message(assigns, :error, items)} #{Backpex.translate("The item is used elsewhere.")}"
  end

  defp error_message(assigns, %Ecto.ConstraintError{type: :foreign_key}, [_item] = items) do
    "#{error_message(assigns, :error, items)} #{Backpex.translate("The item is used elsewhere.")}"
  end

  defp error_message(assigns, %Postgrex.Error{postgres: %{code: :foreign_key_violation}}, items) do
    "#{error_message(assigns, :error, items)} #{Backpex.translate("The items are used elsewhere.")}"
  end

  defp error_message(assigns, %Ecto.ConstraintError{type: :foreign_key}, items) do
    "#{error_message(assigns, :error, items)} #{Backpex.translate("The items are used elsewhere.")}"
  end

  defp error_message(assigns, _error, [_item]) do
    Backpex.translate({"An error occurred while deleting the %{resource}!", %{resource: assigns.singular_name}})
  end

  defp error_message(assigns, _error, items) do
    Backpex.translate(
      {"An error occurred while deleting %{count} %{resources}!",
       %{resources: assigns.plural_name, count: Enum.count(items)}}
    )
  end
end
