defmodule ProplexWeb.UserAuthorization do
  use ProplexWeb, :verified_routes
  import Phoenix.Controller
  import Plug.Conn
  alias Proplex.Authorization

  def require_permission(conn, {resource, action}) do
    user = conn.assigns.current_scope && conn.assigns.current_scope.user

    if user && Authorization.can?(user, action, resource) do
      conn
    else
      conn
      |> put_flash(:error, "You are not authorized to access this page.")
      |> redirect(to: ~p"/")
      |> halt()
    end
  end

  def on_mount({:require_permission, resource, action}, _params, _session, socket) do
    user = socket.assigns.current_scope && socket.assigns.current_scope.user

    if user && Authorization.can?(user, action, resource) do
      {:cont, socket}
    else
      socket
      |> Phoenix.LiveView.put_flash(:error, "You are not authorized to access this page.")
      |> Phoenix.LiveView.redirect(to: ~p"/")
      |> then(&{:halt, &1})
    end
  end
end
