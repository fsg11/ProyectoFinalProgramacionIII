defmodule EmergenciasWeb.NecesidadesLive do
  @moduledoc "Necesidades: registro, filtros, asignación de recursos y cambio de estado."

  use EmergenciasWeb, :live_view

  alias Emergencias.{Necesidad, Necesidades, Recursos, Util}

  @filtros ~w(estado prioridad zona tipo)

  @impl true
  def mount(_parametros, _sesion, socket) do
    {:ok, socket |> assign(:page_title, "Necesidades") |> assign(:filtros, %{}) |> cargar()}
  end

  @impl true
  def handle_info(:datos_actualizados, socket), do: {:noreply, cargar(socket)}

  @impl true
  def handle_event("filtrar", p, socket) do
    filtros = Map.new(@filtros, fn clave -> {clave, param(p, clave)} end)
    {:noreply, socket |> assign(:filtros, filtros) |> cargar()}
  end

  def handle_event("registrar", p, socket) do
    partes = [
      "register_need",
      param(p, "tipo"),
      param(p, "cantidad"),
      param(p, "prioridad"),
      param(p, "zona"),
      param(p, "descripcion"),
      param(p, "destino")
    ]

    {:noreply, socket |> ejecutar(partes) |> cargar()}
  end

  def handle_event("asignar", p, socket) do
    partes = ["assign_resource", param(p, "necesidad"), param(p, "criterio"), param(p, "cantidad")]
    {:noreply, socket |> ejecutar(partes) |> cargar()}
  end

  def handle_event("estado", %{"id" => id, "estado" => estado}, socket) do
    {:noreply, socket |> ejecutar(["update_need", id, estado]) |> cargar()}
  end

  defp cargar(socket) do
    filtros =
      socket.assigns.filtros
      |> Enum.reject(fn {_clave, valor} -> valor == "" end)
      |> Enum.map(fn {clave, valor} -> {clave, Util.normalizar(valor)} end)

    recursos = Recursos.listar()

    socket
    |> assign(:lista, Necesidades.listar(filtros))
    |> assign(:codigos, codigos_zona())
    |> assign(:criterios, Enum.uniq(Enum.map(recursos, & &1.categoria) ++ Enum.map(recursos, & &1.codigo)))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} usuario={@usuario} activo="/necesidades">
      <.encabezado
        titulo="Necesidades"
        subtitulo="Ordenadas por prioridad y antigüedad: la primera abierta es la siguiente a atender."
      />

      <.seccion titulo="Registrar necesidad">
        <form id={"form-necesidad-#{@version}"} phx-submit="registrar" class="formulario rejilla">
          <.selector etiqueta="Tipo" nombre="tipo" opciones={Necesidad.tipos()} />
          <.campo etiqueta="Cantidad" nombre="cantidad" tipo="number" min="1" requerido />
          <.selector etiqueta="Prioridad" nombre="prioridad" opciones={~w(critica alta media baja)} valor="alta" />
          <.selector etiqueta="Zona" nombre="zona" opciones={@codigos} valor={@usuario.zona} />
          <.campo etiqueta="Descripción" nombre="descripcion" requerido ayuda="Punto de atención sector 3" />
          <.campo etiqueta="Destino (opcional)" nombre="destino" ayuda="A01" />
          <div class="acciones-formulario">
            <button type="submit" class="boton boton-primario">Registrar necesidad</button>
          </div>
        </form>
      </.seccion>

      <.resultado resultado={@resultado} />

      <.seccion titulo={"Listado (#{length(@lista)})"}>
        <form id="filtros" phx-change="filtrar" class="filtros">
          <.selector
            etiqueta="Estado"
            nombre="estado"
            opciones={~w(pendiente asignada en_atencion atendida cancelada)}
            valor={@filtros["estado"]}
            vacio="Todos"
          />
          <.selector
            etiqueta="Prioridad"
            nombre="prioridad"
            opciones={~w(critica alta media baja)}
            valor={@filtros["prioridad"]}
            vacio="Todas"
          />
          <.selector etiqueta="Zona" nombre="zona" opciones={@codigos} valor={@filtros["zona"]} vacio="Todas" />
          <.selector etiqueta="Tipo" nombre="tipo" opciones={Necesidad.tipos()} valor={@filtros["tipo"]} vacio="Todos" />
        </form>

        <.vacio :if={@lista == []} texto="No hay necesidades con esos filtros." />
        <.sugerencias id="criterios" opciones={@criterios} />

        <div class="tabla-contenedor">
          <table :if={@lista != []} class="tabla">
            <thead>
              <tr>
                <th>Id</th><th>Tipo</th><th>Prioridad</th><th>Zona</th><th>Descripción</th>
                <th>Avance</th><th>Estado</th><th :if={puede?(@usuario, "assign_resource")}>Acciones</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={n <- @lista} id={"necesidad-#{n.id}"}>
                <td><strong>{n.id}</strong><br /><small>{n.fecha}</small></td>
                <td>{n.tipo}</td>
                <td><.insignia texto={n.prioridad} /></td>
                <td>{n.zona}</td>
                <td>{n.descripcion}<br :if={n.destino != "-"} /><small :if={n.destino != "-"}>destino {n.destino}</small></td>
                <td class="celda-barra"><.barra valor={n.asignada} maximo={n.cantidad} /></td>
                <td><.insignia texto={n.estado} /></td>
                <td :if={puede?(@usuario, "assign_resource")}>
                  <div :if={Necesidad.abierta?(n)} class="acciones-fila">
                    <form id={"asignar-#{n.id}-#{@version}"} phx-submit="asignar" class="en-linea">
                      <input type="hidden" name="necesidad" value={n.id} />
                      <input name="criterio" value={n.tipo} list="criterios" title="Código o categoría del recurso" />
                      <input name="cantidad" type="number" min="1" value={Necesidad.faltante(n)} class="corto" />
                      <button type="submit" class="boton boton-mini boton-primario">Asignar</button>
                    </form>
                    <div class="en-linea">
                      <button
                        :for={estado <- ~w(en_atencion atendida cancelada)}
                        :if={puede?(@usuario, "update_need")}
                        type="button"
                        class="boton boton-mini boton-claro"
                        phx-click="estado"
                        phx-value-id={n.id}
                        phx-value-estado={estado}
                      >
                        {String.replace(estado, "_", " ")}
                      </button>
                    </div>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </.seccion>
    </Layouts.app>
    """
  end
end
