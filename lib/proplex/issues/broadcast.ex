defmodule Proplex.Issues.Broadcast do
  alias Phoenix.PubSub
  alias Proplex.Issues.Issue

  @spec topic_all() :: String.t()
  defp topic_all, do: "issues:all"

  @spec topic_for_reporter(integer()) :: String.t()
  defp topic_for_reporter(user_id), do: "issues:reporter:#{user_id}"

  @spec topic_for_technician(integer()) :: String.t()
  defp topic_for_technician(user_id), do: "issues:technician:#{user_id}"

  @spec topic_for_issue(integer()) :: String.t()
  defp topic_for_issue(issue_id), do: "issues:issue:#{issue_id}"

  def subscribe_all do
    PubSub.subscribe(Proplex.PubSub, topic_all())
  end

  def subscribe_to_reporter(user_id) do
    PubSub.subscribe(Proplex.PubSub, topic_for_reporter(user_id))
  end

  def subscribe_to_technician(user_id) do
    PubSub.subscribe(Proplex.PubSub, topic_for_technician(user_id))
  end

  def subscribe_to_issue(issue_id) do
    PubSub.subscribe(Proplex.PubSub, topic_for_issue(issue_id))
  end

  @spec issue_event(Issue.t(), atom()) :: :ok
  def issue_event(%Issue{} = issue, event) when is_atom(event) do
    message = {:issue_event, event, issue.id}
    PubSub.broadcast(Proplex.PubSub, topic_all(), message)
    PubSub.broadcast(Proplex.PubSub, topic_for_issue(issue.id), message)
    PubSub.broadcast(Proplex.PubSub, topic_for_reporter(issue.reporter_id), message)

    if issue.assigned_technician do
      PubSub.broadcast(
        Proplex.PubSub,
        topic_for_technician(issue.assigned_technician_id),
        message
      )
    end

    :ok
  end

  @spec notify_previous_technician(integer(), integer()) :: :ok
  def notify_previous_technician(previous_tech_id, issue_id)
      when is_integer(previous_tech_id) and is_integer(issue_id) do
    message = {:issue_event, :assigned, issue_id}

    PubSub.broadcast(Proplex.PubSub, topic_for_technician(previous_tech_id), message)

    :ok
  end
end
