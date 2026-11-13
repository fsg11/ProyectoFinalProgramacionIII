defmodule EmergenciasWeb do
  @moduledoc "Interfaz web del sistema (Phoenix LiveView). Cada acción se ejecuta como un comando."

  def static_paths, do: ~w(css favicon.ico)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html]

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      import EmergenciasWeb.Acciones

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller, only: [get_csrf_token: 0]

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML
      import EmergenciasWeb.Componentes

      alias EmergenciasWeb.Layouts
      alias Phoenix.LiveView.JS

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: EmergenciasWeb.Endpoint,
        router: EmergenciasWeb.Router,
        statics: EmergenciasWeb.static_paths()
    end
  end

  defmacro __using__(tipo) when is_atom(tipo), do: apply(__MODULE__, tipo, [])
end
