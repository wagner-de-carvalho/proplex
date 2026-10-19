defmodule Proplex.Authorization.UserRole do
  use Ecto.Schema
  import Ecto.Changeset
  alias Proplex.Accounts.User
  alias Proplex.Authorization.Role

  @fields [:user_id, :property_id, :role_id, :resource, :action, :description]

  schema "user_roles" do
    field :action, :string
    field :description, :string
    field :property_id, :integer
    field :resource, :string

    belongs_to :role, Role
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  def changeset(user_role, attrs) do
    user_role
    |> cast(attrs, @fields)
    |> validate_required([:user_id, :role_id])
    |> unique_constraint([:user_id, :role_id, :property_id],
      name: :user_roles_user_role_property_index
    )
    |> unique_constraint([:user_id, :role_id],
      name: :user_roles_user_role_global_index
    )
  end
end
