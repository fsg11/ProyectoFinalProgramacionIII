defmodule EmergenciasWeb.MascotasLive do
  @moduledoc "Mascotas perdidas y encontradas: reportes, búsqueda de coincidencias y confirmación."

  use EmergenciasWeb, :live_view

  alias Emergencias.{Mascota, Mascotas}

  @impl true
  def mount(_parametros, _sesion, socket) do
    {:ok, socket |> assign(:page_title, "Mascotas") |> assign(:mostrar, false) |> cargar()}
  end

  @impl true
  def handle_info(:datos_actualizados, socket), do: {:noreply, cargar(socket)}

  @impl true
  def handle_event("reportar", p, socket) do
    partes = [
      "report_pet",
      param(p, "tipo"),
      param(p, "especie"),
      blanco(param(p, "nombre"), "desconocido"),
      blanco(param(p, "color"), "-"),
      blanco(param(p, "tamano"), "-"),
      param(p, "zona"),
      blanco(param(p, "contacto"), "-"),
      param(p, "caracteristicas")
    ]

    {:noreply, socket |> ejecutar(partes) |> cargar()}
  end

  def handle_event("buscar", _parametros, socket) do
    {:noreply, socket |> assign(:mostrar, true) |> ejecutar(["match_pets"]) |> cargar()}
  end

  def handle_event("confirmar", %{"perdida" => perdida, "encontrada" => encontrada}, socket) do
    {:noreply, socket |> ejecutar(["confirm_match", perdida, encontrada]) |> cargar()}
  end

  defp cargar(socket) do
    reportes = Mascotas.listar()

    coincidencias = if socket.assigns.mostrar, do: Mascota.buscar_coincidencias(reportes), else: []

    socket
    |> assign(:perdidas, Enum.filter(reportes, &(&1.tipo == "perdida")))
    |> assign(:encontradas, Enum.filter(reportes, &(&1.tipo == "encontrada")))
    |> assign(:coincidencias, coincidencias)
    |> assign(:codigos, codigos_zona())
  end

  defp blanco("", defecto), do: defecto
  defp blanco(valor, _defecto), do: valor

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} usuario={@usuario} activo="/mascotas" tema="mascotas">
      <.encabezado
        titulo="Mascotas perdidas y encontradas"
        decoracion="mascotas"
        subtitulo={"Coincidencia desde #{Mascota.umbral()} puntos: especie 30 · zona 25 · color 20 · tamaño 15 · nombre 10 · características hasta 10."}
      />

      <.seccion titulo="Reportar mascota">
        <form id={"form-mascota-#{@version}"} phx-submit="reportar" class="formulario rejilla">
          <.selector etiqueta="Tipo de reporte" nombre="tipo" opciones={[{"Perdida", "lost"}, {"Encontrada", "found"}]} />
          <.campo etiqueta="Especie" nombre="especie" requerido ayuda="perro" />
          <.campo etiqueta="Nombre" nombre="nombre" ayuda="desconocido" />
          <.campo etiqueta="Color" nombre="color" requerido ayuda="negra" />
          <.campo etiqueta="Tamaño" nombre="tamano" requerido ayuda="mediana" />
          <.selector etiqueta="Zona" nombre="zona" opciones={@codigos} valor={@usuario.zona} />
          <.campo etiqueta="Contacto" nombre="contacto" requerido ayuda="3001234567" />
          <.campo etiqueta="Características" nombre="caracteristicas" ayuda="collar rojo" />
          <div class="acciones-formulario">
            <button type="submit" class="boton boton-primario">Reportar</button>
          </div>
        </form>
      </.seccion>

      <.resultado resultado={@resultado} />

      <.seccion :if={puede?(@usuario, "match_pets")} titulo="Coincidencias">
        <button type="button" class="boton boton-primario" phx-click="buscar">Buscar coincidencias</button>
        <.vacio :if={@mostrar and @coincidencias == []} icono="mascota" texto="No hay coincidencias sobre el umbral." />
        <ul :if={@coincidencias != []} class="coincidencias">
          <li :for={{perdida, encontrada, puntaje} <- @coincidencias}>
            <span class="puntaje">{puntaje} pts</span>
            <span>
              <strong>{perdida.id}</strong> {perdida.especie} «{perdida.nombre}» ↔
              <strong>{encontrada.id}</strong> {encontrada.color}, {encontrada.tamano} en {encontrada.zona}
            </span>
            <button
              :if={puede?(@usuario, "confirm_match")}
              type="button"
              class="boton boton-mini boton-primario"
              phx-click="confirmar"
              phx-value-perdida={perdida.id}
              phx-value-encontrada={encontrada.id}
            >
              Confirmar
            </button>
          </li>
        </ul>
      </.seccion>

      <div class="columnas">
        <.seccion titulo={"Perdidas (#{length(@perdidas)})"}>
          <.vacio :if={@perdidas == []} icono="mascota" texto="Sin reportes de mascotas perdidas." />
          <.ficha :for={m <- @perdidas} mascota={m} />
        </.seccion>
        <.seccion titulo={"Encontradas (#{length(@encontradas)})"}>
          <.vacio :if={@encontradas == []} icono="mascota" texto="Sin reportes de mascotas encontradas." />
          <.ficha :for={m <- @encontradas} mascota={m} />
        </.seccion>
      </div>
    </Layouts.app>
    """
  end

  attr :mascota, :map, required: true

  defp ficha(assigns) do
    ~H"""
    <div class="ficha ficha-mascota" id={"mascota-#{@mascota.id}"}>
      <.animal :if={@mascota.especie in ["perro", "gato"]} tipo={@mascota.especie} class="ficha-animal" />
      <span :if={@mascota.especie not in ["perro", "gato"]} class="ficha-animal ficha-huella"></span>
      <div class="ficha-datos">
        <div class="ficha-cabecera">
          <strong>{@mascota.id}</strong> {@mascota.especie} «{@mascota.nombre}»
          <.insignia texto={@mascota.estado} />
        </div>
        <small>
          {@mascota.color}, {@mascota.tamano} · zona {@mascota.zona} · contacto {@mascota.contacto}
        </small>
        <small :if={@mascota.caracteristicas != ""}>Características: {@mascota.caracteristicas}</small>
        <small :if={@mascota.coincidencia != "-"}>Coincide con {@mascota.coincidencia}</small>
      </div>
    </div>
    """
  end
end
