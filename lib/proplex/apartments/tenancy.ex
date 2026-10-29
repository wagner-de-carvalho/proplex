defmodule Proplex.Apartments.Tenancy do
  use Ecto.Schema
  import Ecto.Changeset
  alias Proplex.Accounts.User
  alias Proplex.Apartments.Apartment

  @fields [:user_id, :apartment_id, :start_date, :end_date]
  @required [:user_id, :apartment_id, :start_date]

  schema "tenancies" do
    field :start_date, :date
    field :end_date, :date

    belongs_to :apartment, Apartment
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tenancy, attrs) do
    tenancy
    |> cast(attrs, @fields)
    |> validate_required(@required)
    |> assoc_constraint(:apartment)
    |> assoc_constraint(:user)
    |> unique_constraint(:apartment_id,
      name: :tenancies_active_apartment_index,
      message: "This apartment already has an active tenant"
    )
    |> unique_constraint(:user_id,
      name: :tenancies_active_user_index,
      message: "This user already has an active tenancy"
    )
  end

  def end_changeset(tenancy, attrs) do
    tenancy
    |> cast(attrs, [:end_date])
    |> validate_required([:end_date])
    |> validate_end_after_start()
  end

  defp validate_end_after_start(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    cond do
      is_nil(start_date) or is_nil(end_date) ->
        changeset

      Date.compare(end_date, start_date) == :lt ->
        add_error(changeset, :end_date, "must be on or after the start date")

      true ->
        changeset
    end
  end
end
