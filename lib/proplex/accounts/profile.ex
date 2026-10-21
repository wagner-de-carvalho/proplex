defmodule Proplex.Accounts.Profile do
  use Ecto.Schema
  import Ecto.Changeset
  alias Phoenix.Naming
  alias Proplex.Accounts.User

  @fields [
    :user_id,
    :first_name,
    :middle_name,
    :last_name,
    :gender,
    :occupation,
    :bio,
    :phone_number,
    :country,
    :city,
    :avatar_url,
    :reputation,
    :average_rating,
    :report_count
  ]

  schema "profiles" do
    field :first_name, :string
    field :middle_name, :string
    field :last_name, :string

    field :gender, Ecto.Enum,
      values: [:male, :female, :prefer_not_to_say],
      default: :prefer_not_to_say

    field :occupation, Ecto.Enum,
      values: [
        :none,
        :mason,
        :carpenter,
        :roofer,
        :plumber,
        :electrician,
        :painter,
        :hvac_technician
      ],
      default: :none

    field :bio, :string
    field :phone_number, :string
    field :country, :string
    field :city, :string
    field :avatar_url, :string
    field :reputation, :integer, default: 100
    field :average_rating, :float, default: 0.0
    field :report_count, :integer, default: 0

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, @fields)
    |> validate_length(:first_name, min: 2, max: 80)
    |> validate_length(:middle_name, min: 2, max: 80)
    |> validate_length(:last_name, min: 2, max: 80)
    |> validate_length(:bio, max: 500)
    |> validate_length(:phone_number, max: 30)
    |> validate_length(:country, max: 80)
    |> validate_length(:city, max: 80)
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> validate_required([:user_id])
  end

  def occupations do
    __MODULE__
    |> Ecto.Enum.values(:occupation)
    |> Enum.map(&{Naming.humanize(Atom.to_string(&1)), &1})
    |> Enum.map(fn {name, value} ->
      case String.split(name, " ") do
        [str_word, atom_word] ->
          {String.upcase(str_word) <> " " <> String.capitalize(atom_word), value}

        [str_word] ->
          {String.capitalize(str_word), value}
      end
    end)
  end

  def genders do
    __MODULE__
    |> Ecto.Enum.values(:gender)
    |> Enum.map(&{Naming.humanize(Atom.to_string(&1)), &1})
  end

  def get_gender(gender) when is_atom(gender) do
    case Enum.find(genders(), fn {_label, value} -> value == gender end) do
      {label, _value} -> label
      nil -> nil
    end
  end
end
