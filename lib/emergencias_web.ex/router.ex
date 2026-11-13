defmodule EmergenciasWeb.Router do
  use EmergenciasWeb, :router

  pipeline :navegador do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EmergenciasWeb.Layouts, :raiz}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", EmergenciasWeb do
    pipe_through :navegador

    get "/", SesionController, :nueva
    post "/sesion", SesionController, :crear
    delete "/sesion", SesionController, :eliminar

    live_session :autenticado, on_mount: EmergenciasWeb.Autenticacion do
      live "/panel", PanelLive
      live "/zonas", ZonasLive
      live "/necesidades", NecesidadesLive
      live "/recursos", RecursosLive
      live "/personas", PersonasLive
      live "/mascotas", MascotasLive
      live "/albergues", AlberguesLive
      live "/usuarios", UsuariosLive
    end
  end
end
