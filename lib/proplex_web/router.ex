defmodule ProplexWeb.Router do
  use ProplexWeb, :router

  import ProplexWeb.UsersAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ProplexWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_users
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ProplexWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", ProplexWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:proplex, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ProplexWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", ProplexWeb do
    pipe_through [:browser, :require_authenticated_users]

    live_session :require_authenticated_users,
      on_mount: [{ProplexWeb.UsersAuth, :require_authenticated}] do
      live "/users/settings", UsersLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UsersLive.Settings, :confirm_email
    end

    post "/users/update-password", UsersSessionController, :update_password
  end

  scope "/", ProplexWeb do
    pipe_through [:browser]

    live_session :current_users,
      on_mount: [{ProplexWeb.UsersAuth, :mount_current_scope}] do
      live "/users/register", UsersLive.Registration, :new
      live "/users/log-in", UsersLive.Login, :new
      live "/users/log-in/:token", UsersLive.Confirmation, :new
    end

    post "/users/log-in", UsersSessionController, :create
    delete "/users/log-out", UsersSessionController, :delete
  end
end
