defmodule Proplex.Workers.IssueAssignedEmail do
  use Oban.Worker, queue: :mailers

  alias Oban.Job
  alias Proplex.Issues
  alias Proplex.Issues.IssueNotifier

  @impl Oban.Worker
  def perform(%Job{args: %{"issue_id" => issue_id}}) do
    case Issues.get_issue(issue_id, include_deleted: true) do
      nil ->
        {:cancel, "issue #{issue_id} not found"}

      %{assigned_technician: nil} ->
        {:cancel, "issue #{issue_id} has not assigned technician"}

      issue ->
        case IssueNotifier.deliver_issue_assigned(issue) do
          {:ok, _email} -> :ok
          {:error, _} = error -> error
        end
    end
  end
end
