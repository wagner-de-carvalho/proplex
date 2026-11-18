defmodule Proplex.Apartments do
  import Ecto.Query, warn: false
  require Logger
  alias Proplex.Accounts.User
  alias Proplex.Authorization.UserRole
  alias Proplex.Apartments.Apartment
  alias Proplex.Apartments.Tenancy
  alias Proplex.Repo
  alias Ecto.Changeset

  def list_apartments(opts \\ []) do
    include_archived? = Keyword.get(opts, :include_archived, false)

    Apartment
    |> order_by([a], asc: a.building_name, asc: a.unit_number)
    |> filter_archived(include_archived?)
    |> Repo.all()
  end

  defp filter_archived(query, true), do: query
  defp filter_archived(query, false), do: query |> where([a], is_nil(a.archived_at))

  def get_apartment(id), do: Repo.get(Apartment, id)
  def get_apartment!(id), do: Repo.get!(Apartment, id)

  def create_apartment(attrs \\ %{}) do
    %Apartment{}
    |> Apartment.changeset(attrs)
    |> Repo.insert()
    |> then(fn
      {:ok, apartment} ->
        Logger.info("Apartment created",
          event: :apartment_created,
          apartment_id: apartment.id,
          building_name: apartment.building_name,
          unit_number: apartment.unit_number,
          floor: apartment.floor
        )

        {:ok, apartment}

      other ->
        other
    end)
  end

  def update_apartment(%Apartment{} = apartment, attrs) do
    apartment
    |> Apartment.changeset(attrs)
    |> Repo.update()
    |> then(fn
      {:ok, apartment} ->
        Logger.info("Apartment updated",
          event: :apartment_updated,
          apartment_id: apartment.id,
          building_name: apartment.building_name,
          unit_number: apartment.unit_number,
          floor: apartment.floor
        )

        {:ok, apartment}

      other ->
        other
    end)
  end

  def archive_apartment(%Apartment{} = apartment) do
    apartment
    |> get_active_tenancy_for_apartment()
    |> then(fn
      nil -> update_apartment_archived_at(apartment)
      _tenancy -> {:error, :active_tenancy_exists}
    end)
  end

  defp update_apartment_archived_at(%Apartment{} = apartment) do
    apartment
    |> Changeset.change(archived_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update()
    |> then(fn
      {:ok, apartment} ->
        Logger.info("Apartment archived",
          event: :apartment_archived,
          apartment_id: apartment.id,
          building_name: apartment.building_name,
          unit_number: apartment.unit_number,
          floor: apartment.floor
        )

        {:ok, apartment}

      other ->
        other
    end)
  end

  def unarchive_apartment(%Apartment{archived_at: nil} = apartment) do
    {:ok, apartment}
  end

  def unarchive_apartment(%Apartment{} = apartment) do
    apartment
    |> Changeset.change(archived_at: nil)
    |> Repo.update()
    |> then(fn
      {:ok, apartment} ->
        Logger.info("Apartment unarchived",
          event: :apartment_unarchived,
          apartment_id: apartment.id,
          building_name: apartment.building_name,
          unit_number: apartment.unit_number,
          floor: apartment.floor
        )

        {:ok, apartment}

      other ->
        other
    end)
  end

  def change_apartment(%Apartment{} = apartment, attrs \\ %{}) do
    Apartment.changeset(apartment, attrs)
  end

  def start_tenancy(attrs \\ %{}) do
    apartment_id = attrs[:apartment_id] || attrs["apartment_id"]
    apartment = apartment_id && get_apartment(apartment_id)

    if apartment && apartment.archived_at do
      {:error, :apartment_archived}
    else
      insert_tenancy(attrs)
    end
  end

  defp insert_tenancy(attrs) do
    %Tenancy{}
    |> Tenancy.create_changeset(attrs)
    |> Repo.insert()
    |> then(fn
      {:ok, tenancy} ->
        Logger.info("Tenancy started",
          event: :tenancy_started,
          tenancy_id: tenancy.id,
          user_id: tenancy.user_id,
          apartment_id: tenancy.apartment_id,
          start_date: Date.to_iso8601(tenancy.start_date)
        )

        {:ok, tenancy}

      other ->
        other
    end)
  end

  def end_tenancy(%Tenancy{} = tenancy, %Date{} = end_date) do
    tenancy
    |> Tenancy.end_changeset(%{end_date: end_date})
    |> Repo.update()
    |> then(fn
      {:ok, tenancy} ->
        Logger.info("Tenancy ended",
          event: :tenancy_ended,
          tenancy_id: tenancy.id,
          user_id: tenancy.user_id,
          apartment_id: tenancy.apartment_id,
          end_date: Date.to_iso8601(tenancy.end_date),
          tenant_name: tenancy.tenant_name
        )

        {:ok, tenancy}

      other ->
        other
    end)
  end

  def get_current_apartment_for_user(%{id: user_id}) do
    Tenancy
    |> join(:inner, [t], a in assoc(t, :apartment))
    |> where([t], t.user_id == ^user_id and is_nil(t.end_date))
    |> select([_t, a], a)
    |> Repo.one()
  end

  def get_current_tenancy_for_apartment(%{id: user_id}) do
    Tenancy
    |> join(:inner, [t], a in assoc(t, :apartment))
    |> where([t], t.user_id == ^user_id and is_nil(t.end_date))
    |> select([_t, a], a)
    |> Repo.one()
  end

  def get_active_tenancy_for_user(%{id: user_id}) do
    Tenancy
    |> where([t], t.user_id == ^user_id and is_nil(t.end_date))
    |> preload(:apartment)
    |> Repo.one()
  end

  defp get_active_tenancy_for_apartment(%Apartment{id: apartment_id}) do
    Tenancy
    |> where([t], t.apartment_id == ^apartment_id and is_nil(t.end_date))
    |> Repo.one()
  end

  def list_tenancies_for_user(%{id: user_id}) do
    Tenancy
    |> where([t], t.user_id == ^user_id)
    |> order_by([t], desc: t.start_date)
    |> preload(:apartment)
    |> Repo.all()
  end

  def list_tenancies_for_apartment(%Apartment{id: apartment_id}) do
    Tenancy
    |> where([t], t.apartment_id == ^apartment_id)
    |> order_by([t], desc: t.start_date)
    |> preload(:user)
    |> Repo.all()
  end

  def list_apartments_with_current_tenant(opts \\ []) do
    Apartment
    |> join(:left, [a], t in assoc(a, :tenancies),
      on: t.apartment_id == a.id and is_nil(t.end_date)
    )
    |> join(:left, [_a, t], u in assoc(t, :user))
    |> order_by([a, _t, _u], asc: a.building_name, asc: a.unit_number)
    |> select([a, _t, u], %{apartment: a, current_tenant: u})
    |> maybe_filter_archived(Keyword.get(opts, :include_archived, true))
    |> maybe_filter_building(Keyword.get(opts, :building_name))
    |> maybe_filter_occupancy(Keyword.get(opts, :occupancy, :all))
    |> Repo.all()
  end

  defp maybe_filter_archived(query, true), do: query

  defp maybe_filter_archived(query, false) do
    where(query, [a, _t, _u], is_nil(a.archived_at))
  end

  defp maybe_filter_building(query, nil), do: query

  defp maybe_filter_building(query, name) when is_binary(name) and name != "" do
    where(query, [a, _t, _u], a.building_name == ^name)
  end

  defp maybe_filter_building(query, _), do: query

  defp maybe_filter_occupancy(query, :all), do: query

  defp maybe_filter_occupancy(query, :vacant) do
    where(query, [_a, t, _u], is_nil(t.id))
  end

  defp maybe_filter_occupancy(query, :occupied) do
    where(query, [_a, t, _u], not is_nil(t.id))
  end

  def list_eligible_tenants do
    active_tenant_ids_query =
      Tenancy
      |> where([t], is_nil(t.end_date))
      |> select([t], t.user_id)

    User
    |> join(:inner, [u], ur in UserRole, on: ur.user_id == u.id)
    |> join(:inner, [_u, ur], r in assoc(ur, :role))
    |> where([_u, _ur, r], r.name == "tenant")
    |> where([u, _ur, r], u.id not in subquery(active_tenant_ids_query))
    |> order_by([u, _ur, _r], u.username)
    |> distinct(true)
    |> Repo.all()
  end

  def list_building_names do
    Apartment
    |> distinct(true)
    |> select([a], a.building_name)
    |> order_by([a], a.building_name)
    |> Repo.all()
  end
end
