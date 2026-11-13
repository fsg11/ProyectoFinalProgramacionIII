defmodule EmergenciasWeb.Endpoint do
  @moduledoc "Punto de entrada HTTP de la interfaz web."

  use Phoenix.Endpoint, otp_app: :emergencias

  @opciones_sesion [
    store: :cookie,
    key: "_emergencias_key",
    signing_salt: "p7Lr2XqW",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @opciones_sesion]],
    longpoll: [connect_info: [session: @opciones_sesion]]

  plug Plug.Static, at: "/", from: :emergencias, gzip: false, only: EmergenciasWeb.static_paths()
  plug Plug.Static, at: "/js", from: {:phoenix, "priv/static"}, only: ~w(phoenix.min.js)

  plug Plug.Static,
    at: "/js",
    from: {:phoenix_live_view, "priv/static"},
    only: ~w(phoenix_live_view.min.js)

  plug Plug.RequestId

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @opciones_sesion
  plug EmergenciasWeb.Router
end
