defmodule Proplex.Issues do
  import Ecto.Query, warn: false
  require Logger
  alias Proplex.Apartments
  alias Proplex.Issues.Issue
  alias Proplex.Repo

  def report_issue(%{id: reporter_id} = reporter, attrs) do
    case Apartments.get_current_tenancy_for_apartment(reporter) do
      nil ->
        {:error, :no_active_tenancy}

      apartment ->
        attrs =
          attrs
          |> normalize_attrs()
          |> Map.put("reporter_id", reporter_id)
          |> Map.put("apartment_id", apartment.id)

        %Issue{}
        |> Issue.changeset(attrs)
        |> Repo.insert()
        |> then(fn
          {:ok, issue} ->
            Logger.info("Issue reported",
              event: :issue_reported,
              issue_id: issue.id,
              reporter_id: reporter_id,
              apartment_id: apartment.id,
              priority: issue.priority
            )

            {:ok, issue}

          other ->
            other
        end)
    end
  end

  def assign_technician(%Issue{} = issue, technician_id) do
    issue
    |> Issue.changeset(%{technician_id: technician_id})
    |> Repo.update()
    |> then(fn
      {:ok, issue} ->
        Logger.info("Issue assigned to technician",
          event: :issue_assigned,
          issue_id: issue.id,
          assigned_technician_id: technician_id
        )

        {:ok, issue}

      other ->
        other
    end)
  end

  defp normalize_attrs(value) do
    %{}
  end

  def start_progress(%Issue{status: :reported} = issue) do
    issue
    |> Issue.start_progress_changeset()
    |> Repo.update()
    |> then(fn
      {:ok, issue} ->
        Logger.info("Issue moved to in_progress",
          event: :issue_progress_started,
          issue_id: issue.id,
          assigned_technician_id: issue.assigned_technician_id
        )

        {:ok, issue}

      other ->
        other
    end)
  end

  def resolve_issue(%Issue{status: :in_progress} = issue) do
    issue
    |> Issue.resolve_changeset()
    |> Repo.update()
    |> then(fn
      {:ok, issue} ->
        Logger.info("Issue resolved",
          event: :issue_resolved,
          issue_id: issue.id,
          assigned_technician_id: issue.assigned_technician_id,
          resolved_on: Date.to_iso8601(issue.resolved_on)
        )

        {:ok, issue}

      other ->
        other
    end)
  end

  def delete_issue(%Issue{} = issue) do
    issue
    |> Issue.soft_delete_changeset()
    |> Repo.update()
    |> then(fn
      {:ok, issue} ->
        Logger.warning("Issue soft deleted",
          event: :issue_deleted,
          issue_id: issue.id,
          reporter_id: issue.reporter_id,
          resolved_on: Date.to_iso8601(issue.resolved_on)
        )

        {:ok, issue}

      other ->
        other
    end)
  end

  def get_issue(id, opts \\ []) do
    include_deleted? = Keyword.get(opts, :include_deleted, false)

    Issue
    |> where([i], i.id == ^id)
    |> maybe_include_deleted(include_deleted?)
    |> preload([:reporter, :apartment, :assigned_technician])
    |> Repo.one()
  end

  def get_issue!(id, opts \\ []) do
    case get_issue(id, opts) do
      nil -> raise Ecto.NoResultsError, queryable: Issue, id: id
      issue -> issue
    end
  end

  defp maybe_include_deleted(query, opts) when is_list(opts) do
    if Keyword.get(opts, :include_deleted, false) do
      query
    else
      exclude_deleted(query)
    end
  end

  defp maybe_include_deleted(query, true), do: query

  defp maybe_include_deleted(query, false) do
    where(query, [i], is_nil(i.deleted_at))
    |> exclude_deleted()
  end

  defp exclude_deleted(query) do
    where(query, [i], is_nil(i.deleted_at))
  end

  def list_issues_for_reporter(%{id: reporter_id}, opts \\ []) do
    Issue
    |> where([i], i.reporter_id == ^reporter_id)
    |> maybe_include_deleted(opts)
    |> order_by([i], desc: i.inserted_at)
    |> preload([:reporter, :apartment, :assigned_technician])
    |> Repo.all()
  end

  def list_issues_for_technician(%{id: technician_id}, opts \\ []) do
    Issue
    |> where([i], i.assigned_technician_id == ^technician_id)
    |> maybe_include_deleted(opts)
    |> order_by([i], desc: i.inserted_at)
    |> preload([:reporter, :apartment, :assigned_technician])
    |> Repo.all()
  end

  def list_all_issues(opts \\ []) do
    Issue
    |> maybe_include_deleted(opts)
    |> maybe_filter_status(opts)
    |> maybe_filter_priority(opts)
    |> maybe_filter_unassigned(opts)
    |> order_by([i], desc: i.inserted_at)
    |> preload([:reporter, :apartment, :assigned_technician])
    |> Repo.all()
  end

  def change_issue_report(%Issue{} = issue \\ %Issue{}, attrs \\ []) do
    Issue.report_changeset(issue, attrs)
  end

  def change_issue_assign(%Issue{} = issue \\ %Issue{}, attrs \\ []) do
    Issue.assign_changeset(issue, attrs)
  end

  defp maybe_filter_status(query, opts) do
    case Keyword.get(opts, :status) do
      nil -> query
      status when is_atom(status) -> where(query, [i], i.status == ^status)
    end
  end

  defp maybe_filter_priority(query, opts) do
    case Keyword.get(opts, :priority) do
      nil -> query
      priority when is_atom(priority) -> where(query, [i], i.priority == ^priority)
    end
  end

  defp maybe_filter_unassigned(query, opts) do
    if Keyword.get(opts, :unassigned_only, false) do
      where(query, [i], is_nil(i.assigned_technician_id))
    else
      query
    end
  end

  defp normalize_attrs(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end
end
