defmodule Proplex.Repo.Migrations.RenameUsersIdToUserIdInUsersTokens do
  use Ecto.Migration

  def change do
    rename table(:users_tokens), :users_id, to: :user_id

    execute "ALTER INDEX users_tokens_users_id_index RENAME TO users_tokens_user_id_index",
            "ALTER INDEX users_tokens_user_id_index RENAME TO users_tokens_users_id_index"
  end
end
