defmodule EmergenciasWeb.AlberguesLive do
  @moduledoc "Albergues: ocupación, ingresos y salidas de personas."

  use EmergenciasWeb, :live_view

  alias Emergencias.{Albergue, Albergues, Personas}

  @impl true
  def mount(_parametros, _sesion, socket) do
    {:ok, socket |> assign(:page_title, "Albergues") |> cargar()}
  end

  @impl true
  def handle_info(:datos_actualizados, socket), do: {:noreply, cargar(socket)}

  @impl true
  def handle_event("registrar", p, socket) do
    partes = ["register_shelter", param(p, "codigo"), param(p, "nombre"), param(p, "zona"), param(p, "capacidad")]
    {:noreply, socket |> ejecutar(partes) |> cargar()}
  end

  def handle_event("ingresar", p, socket) do
    {:noreply, socket |> ejecutar(["register_entry", param(p, "codigo"), param(p, "documento")]) |> cargar()}
  end

  def handle_event("salida", %{"codigo" => codigo, "documento" => documento}, socket) do
    {:noreply, socket |> ejecutar(["register_exit", codigo, documento]) |> cargar()}
  end

  defp cargar(socket) do
    personas = Personas.buscar([])

    socket
    |> assign(:albergues, Albergues.reporte_ocupacion())
    |> assign(:nombres, Map.new(personas, &{&1.documento, &1.nombre}))
    |> assign(:candidatas, Enum.filter(personas, &(&1.estado not in ["en_albergue", "reunificada"])))
    |> assign(:codigos, codigos_zona())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} usuario={@usuario} activo="/albergues">
      <.encabezado
        titulo="Albergues"
        subtitulo="Ordenados de mayor a menor ocupación. Una persona solo puede estar en un albergue a la vez."
      />

      <div class="columnas">
        <.seccion :if={puede?(@usuario, "register_entry")} titulo="Registrar ingreso">
          <form id={"form-ingreso-#{@version}"} phx-submit="ingresar" class="formulario rejilla">
            <.selector etiqueta="Albergue" nombre="codigo" opciones={Enum.map(@albergues, &{"#{&1.codigo} · #{&1.nombre}", &1.codigo})} />
            <.campo etiqueta="Documento de la persona" nombre="documento" requerido lista="candidatas" />
            <.sugerencias id="candidatas" opciones={Enum.map(@candidatas, & &1.documento)} />
            <div class="acciones-formulario">
              <button type="submit" class="boton boton-primario" disabled={@albergues == []}>Registrar ingreso</button>
            </div>
          </form>
          <p class="nota">La persona debe estar registrada y su estado debe permitir pasar a «en albergue».</p>
        </.seccion>

        <.seccion :if={puede?(@usuario, "register_shelter")} titulo="Registrar albergue">
          <form id={"form-albergue-#{@version}"} phx-submit="registrar" class="formulario rejilla">
            <.campo etiqueta="Código" nombre="codigo" requerido ayuda="A01" />
            <.campo etiqueta="Nombre" nombre="nombre" requerido ayuda="Albergue Norte" />
            <.selector etiqueta="Zona" nombre="zona" opciones={@codigos} valor={@usuario.zona} />
            <.campo etiqueta="Capacidad" nombre="capacidad" tipo="number" min="1" requerido />
            <div class="acciones-formulario">
              <button type="submit" class="boton boton-primario">Registrar</button>
            </div>
          </form>
        </.seccion>
      </div>

      <.resultado resultado={@resultado} />

      <.vacio :if={@albergues == []} texto="No hay albergues registrados." />
      <div class="albergues">
        <article :for={a <- @albergues} class="albergue" id={"albergue-#{a.codigo}"}>
          <header>
            <div>
              <strong>{a.codigo}</strong> {a.nombre}
              <small>zona {a.zona}</small>
            </div>
            <.insignia :if={Albergue.ocupacion(a) >= a.capacidad} texto="lleno" />
          </header>
          <.barra valor={Albergue.ocupacion(a)} maximo={a.capacidad} />
          <.vacio :if={Albergue.ocupacion(a) == 0} texto="Sin personas alojadas." />
          <ul class="ocupantes">
            <li :for={documento <- Enum.sort(a.ocupantes)}>
              <span><strong>{documento}</strong> {Map.get(@nombres, documento, "(sin registro)")}</span>
              <button
                :if={puede?(@usuario, "register_exit")}
                type="button"
                class="boton boton-mini boton-claro"
                phx-click="salida"
                phx-value-codigo={a.codigo}
                phx-value-documento={documento}
              >
                Registrar salida
              </button>
            </li>
          </ul>
        </article>
      </div>
    </Layouts.app>
    """
  end
end
