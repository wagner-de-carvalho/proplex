defmodule Proplex.Authorization do
  import Ecto.Query, warn: false
  alias Proplex.Authorization.Permission
  alias Proplex.Authorization.Role
  alias Proplex.Authorization.UserRole
  alias Proplex.Repo

  def can?(user, action, resource, opts \\ []) do
    action_str = to_string(action)
    resource_str = to_string(resource)
    property_id = Keyword.get(opts, :property_id)

    UserRole
    |> join(:inner, [ur], r in assoc(ur, :role))
    |> join(:inner, [ur, r], rp in "role_permissions", on: rp.role_id == r.id)
    |> join(:inner, [ur, r, rp], p in Permission, on: p.id == rp.permission_id)
    |> where([ur], ur.user_id == ^user.id)
    |> where([ur, r, rp, p], p.resource == ^resource_str)
    |> where([ur, r, rp, p], p.action == ^action_str)
    |> filter_user_role_by_property_id(property_id)
    |> Repo.exists?()
  end

  defp filter_user_role_by_property_id(query, nil), do: query

  defp filter_user_role_by_property_id(query, property_id) do
    where(query, [ur], ur.property_id == ^property_id or is_nil(ur.property_id))
  end

  defp filter_exact_property_id(query, nil), do: where(query, [ur], is_nil(ur.property_id))

  defp filter_exact_property_id(query, property_id),
    do: where(query, [ur], ur.property_id == ^property_id)

  def revoke_role(user, role_name, opts \\ []) do
    property_id = Keyword.get(opts, :property_id)

    with %Role{} = role <- get_role_by_name(role_name) do
      UserRole
      |> where([ur], ur.user_id == ^user.id)
      |> where([ur], ur.role_id == ^role.id)
      |> filter_exact_property_id(property_id)
      |> Repo.delete_all()
      |> then(fn
        {count, _} when count > 0 -> :ok
        _ -> {:error, :not_found}
      end)
    else
      nil -> {:error, :role_not_found}
    end
  end

  def assign_role(user, role_name, opts \\ []) do
    property_id = Keyword.get(opts, :property_id)

    with %Role{} = role <- get_role_by_name(role_name) do
      %UserRole{}
      |> UserRole.changeset(%{
        user_id: user.id,
        role_id: role.id,
        property_id: property_id
      })
      |> Repo.insert()
    else
      nil -> {:error, :role_not_found}
    end
  end

  def has_role?(user, role_name) do
    UserRole
    |> join(:inner, [ur], r in assoc(ur, :role))
    |> where([ur, r], ur.user_id == ^user.id)
    |> where([ur, r], r.name == ^to_string(role_name))
    |> Repo.exists?()
  end

  defp get_role_by_name(role_name) do
    Repo.get_by(Role, name: to_string(role_name))
  end

  def list_user_roles(user) do
    UserRole
    |> join(:inner, [ur], r in assoc(ur, :role))
    |> where([ur], ur.user_id == ^user.id)
    |> select([ur, r], %{role: r.name, property_id: ur.property_id})
    |> Repo.all()
  end

  def list_roles do
    Role
    |> order_by([r], asc: r.name)
    |> preload(:permissions)
    |> Repo.all()
  end

  def list_permissions do
    Permission
    |> order_by([p], asc: p.resource, asc: p.action)
    |> preload(:roles)
    |> Repo.all()
  end
end
