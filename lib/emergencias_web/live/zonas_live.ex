defmodule EmergenciasWeb.ZonasLive do
  @moduledoc "Árbol zona → sector → punto de atención y registro de zonas."

  use EmergenciasWeb, :live_view

  alias Emergencias.{Zona, Zonas}

  @impl true
  def mount(_parametros, _sesion, socket) do
    {:ok, socket |> assign(:page_title, "Zonas") |> cargar()}
  end

  @impl true
  def handle_info(:datos_actualizados, socket), do: {:noreply, cargar(socket)}

  @impl true
  def handle_event("registrar", p, socket) do
    afectados = if param(p, "afectados") == "", do: "0", else: param(p, "afectados")

    partes = ["register_zone", param(p, "codigo"), param(p, "nombre"), param(p, "nivel"), afectados, param(p, "padre")]
    {:noreply, socket |> ejecutar(partes) |> cargar()}
  end

  def handle_event("ver", %{"codigo" => codigo}, socket) do
    {:noreply, ejecutar(socket, ["zone_status", codigo])}
  end

  defp cargar(socket) do
    socket
    |> assign(:arbol, Zonas.arbol())
    |> assign(:codigos, codigos_zona())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} usuario={@usuario} activo="/zonas">
      <.encabezado
        titulo="Zonas afectadas"
        subtitulo="Jerarquía zona → sector → punto de atención. Los afectados se acumulan recorriendo el árbol."
      />

      <div class="columnas columnas-2-1">
        <.seccion titulo="Estructura">
          <.vacio :if={@arbol == []} texto="Aún no hay zonas registradas." />
          <.nodos nodos={@arbol} />
        </.seccion>

        <.seccion :if={puede?(@usuario, "register_zone")} titulo="Registrar zona, sector o punto">
          <form id={"form-zona-#{@version}"} phx-submit="registrar" class="formulario">
            <.campo etiqueta="Código" nombre="codigo" requerido ayuda="sector3" />
            <.campo etiqueta="Nombre" nombre="nombre" requerido ayuda="Sector 3" />
            <.selector etiqueta="Nivel de afectación" nombre="nivel" opciones={Zona.niveles()} valor="medio" />
            <.campo etiqueta="Personas afectadas" nombre="afectados" tipo="number" min="0" ayuda="0" />
            <.selector
              etiqueta="Pertenece a"
              nombre="padre"
              opciones={@codigos}
              vacio="— Ninguna (zona principal) —"
            />
            <p class="nota">Una zona dentro de otra es un sector; dentro de un sector, un punto de atención.</p>
            <button type="submit" class="boton boton-primario">Registrar</button>
          </form>
        </.seccion>
      </div>

      <.resultado resultado={@resultado} />
    </Layouts.app>
    """
  end

  attr :nodos, :list, required: true

  # Componente recursivo: dibuja cada nodo y sus hijos.
  defp nodos(assigns) do
    ~H"""
    <ul :if={@nodos != []} class="arbol">
      <li :for={nodo <- @nodos}>
        <div class="nodo">
          <.insignia texto={nodo.zona.tipo} />
          <strong>{nodo.zona.codigo}</strong>
          <span>{nodo.zona.nombre}</span>
          <.insignia texto={nodo.zona.nivel} />
          <small>
            {nodo.zona.afectados} afectados · {Zona.total_afectados(nodo)} con sus sectores
          </small>
          <button type="button" class="boton boton-mini" phx-click="ver" phx-value-codigo={nodo.zona.codigo}>
            Ver estado
          </button>
        </div>
        <.nodos nodos={nodo.hijos} />
      </li>
    </ul>
    """
  end
end
