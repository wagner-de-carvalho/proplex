defmodule Proplex.Workers.IssueResolvedEmail do
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
        {:cancel, "issue #{issue_id} has no assigned technician at resolve time"}

      issue ->
        case IssueNotifier.deliver_issue_resolved(issue) do
          {:ok, _email} -> :ok
          {:error, _} = error -> error
        end
    end
  end
end
