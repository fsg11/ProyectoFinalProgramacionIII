defmodule EmergenciasWeb.Layouts do
  @moduledoc "Estructura de las páginas: documento HTML base y marco con menú lateral."

  use EmergenciasWeb, :html

  alias Emergencias.Usuario

  # {ruta, texto, ícono, comando cuyo permiso se exige (nil = todos)}
  @menu [
    {"/panel", "Panel general", "◉", nil},
    {"/zonas", "Zonas", "⌖", nil},
    {"/necesidades", "Necesidades", "☰", nil},
    {"/recursos", "Recursos", "▣", nil},
    {"/personas", "Personas y mensajes", "☺", nil},
    {"/mascotas", "Mascotas", "♣", nil},
    {"/albergues", "Albergues", "⌂", nil},
    {"/usuarios", "Usuarios y roles", "⚑", "set_role"}
  ]

  @doc "Documento HTML base (se usa en todas las páginas)."
  def raiz(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="es">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={get_csrf_token()} />
        <title>{assigns[:page_title] || "Emergencias"} · Coordinación de emergencias</title>
        <link rel="stylesheet" href={~p"/css/app.css"} />
        <script defer src="/js/phoenix.min.js">
        </script>
        <script defer src="/js/phoenix_live_view.min.js">
        </script>
        <script>
          window.addEventListener("DOMContentLoaded", () => {
            const csrf = document.querySelector("meta[name='csrf-token']").getAttribute("content");
            const liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
              params: { _csrf_token: csrf }
            });
            liveSocket.connect();
            window.liveSocket = liveSocket;
          });
        </script>
      </head>
      <body>
        {@inner_content}
      </body>
    </html>
    """
  end

  attr :flash, :map, required: true
  attr :usuario, :any, required: true
  attr :activo, :string, required: true
  attr :tema, :string, default: nil, doc: "estilo temático de la página: \"mascotas\" o \"personas\""
  slot :inner_block, required: true

  @doc "Marco de las páginas internas: menú lateral, avisos y contenido."
  def app(assigns) do
    assigns =
      assign(
        assigns,
        :menu,
        Enum.filter(@menu, fn {_ruta, _texto, _icono, comando} ->
          comando == nil or EmergenciasWeb.Acciones.puede?(assigns.usuario, comando)
        end)
      )

    ~H"""
    <div class="marco">
      <aside class="lateral">
        <div class="marca">
          <.logo />
          <div>
            <strong>Emergencias</strong>
            <small>Coordinación y ayuda</small>
          </div>
        </div>

        <nav class="menu">
          <.link
            :for={{ruta, texto, icono, _comando} <- @menu}
            navigate={ruta}
            class={["menu-item", ruta == @activo && "activo"]}
          >
            <span class="menu-icono">{icono}</span> {texto}
          </.link>
        </nav>

        <div class="perfil">
          <.animal tipo="gato" class="gato-asomado" />
          <div class="perfil-nombre">{@usuario.nombre}</div>
          <div class="perfil-datos">
            @{@usuario.usuario} · <.insignia texto={@usuario.tipo} />
          </div>
          <div class="perfil-datos">Zona: {@usuario.zona} · Nivel {Usuario.nivel(@usuario.tipo)}</div>
          <form action="/sesion" method="post">
            <input type="hidden" name="_method" value="delete" />
            <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
            <button type="submit" class="boton boton-claro boton-bloque">Cerrar sesión</button>
          </form>
        </div>
      </aside>

      <main class={["contenido", @tema && "tema-#{@tema}"]}>
        <.avisos flash={@flash} />
        {render_slot(@inner_block)}
      </main>
    </div>
    """
  end
end
