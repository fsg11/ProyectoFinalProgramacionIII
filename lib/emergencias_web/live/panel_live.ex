defmodule EmergenciasWeb.PanelLive do
  @moduledoc "Panel general: resumen del estado de la emergencia en tiempo real."

  use EmergenciasWeb, :live_view

  alias Emergencias.{Albergue, Albergues, Mascotas, Mensajes, Necesidades}
  alias Emergencias.{Personas, Recursos}

  @umbral_critico 20

  @impl true
  def mount(_parametros, _sesion, socket) do
    {:ok, socket |> assign(:page_title, "Panel general") |> cargar()}
  end

  @impl true
  def handle_info(:datos_actualizados, socket), do: {:noreply, cargar(socket)}

  @impl true
  def handle_event("simular", _parametros, socket) do
    {:noreply, socket |> ejecutar(["simulate_conflict"]) |> cargar()}
  end

  defp cargar(socket) do
    necesidades = Necesidades.resumen()
    personas = Personas.resumen()
    mensajes = Mensajes.resumen()
    mascotas = Mascotas.resumen()

    socket
    |> assign(:umbral, @umbral_critico)
    |> assign(:recursos, Recursos.resumen())
    |> assign(:criticos, Recursos.criticos(@umbral_critico))
    |> assign(:necesidades, necesidades)
    |> assign(:abiertas, necesidades.por_prioridad |> Map.values() |> Enum.sum())
    |> assign(:pendientes, Necesidades.pendientes() |> Enum.take(6))
    |> assign(:personas, personas)
    |> assign(:mensajes, mensajes)
    |> assign(:mascotas, mascotas)
    |> assign(:albergues, Albergues.resumen())
    |> assign(:lista_albergues, Albergues.reporte_ocupacion() |> Enum.take(6))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} usuario={@usuario} activo="/panel">
      <.encabezado
        titulo="Panel general"
        subtitulo="Estado de la atención en tiempo real. Se actualiza solo cuando cualquier usuario hace un cambio."
      />

      <div class="tarjetas">
        <.tarjeta
          titulo="Necesidades abiertas"
          valor={@abiertas}
          detalle={"#{Map.get(@necesidades.por_prioridad, "critica", 0)} críticas · #{@necesidades.total} en total"}
          tono={if Map.get(@necesidades.por_prioridad, "critica", 0) > 0, do: "rojo", else: "neutro"}
        />
        <.tarjeta
          titulo="Lotes de recursos"
          valor={@recursos.lotes}
          detalle={"#{length(@criticos)} críticos · #{@recursos.agotados} agotados"}
          tono={if @criticos != [], do: "naranja", else: "neutro"}
        />
        <.tarjeta
          titulo="Personas registradas"
          valor={@personas.total}
          detalle={"#{Map.get(@personas.por_estado, "en_albergue", 0)} en albergue · #{Map.get(@personas.por_estado, "reunificada", 0)} reunificadas"}
        />
        <.tarjeta
          titulo="Ocupación de albergues"
          valor={"#{@albergues.ocupacion}/#{@albergues.capacidad}"}
          detalle={"#{@albergues.total} albergues"}
          tono="azul"
        />
        <.tarjeta
          titulo="Mensajes familiares"
          valor={@mensajes.total}
          detalle={"#{Map.get(@mensajes.por_estado, "pendiente", 0)} pendientes de entrega"}
        />
        <.tarjeta
          titulo="Reportes de mascotas"
          valor={@mascotas.total}
          detalle={"#{Map.get(@mascotas.por_estado, "resuelta", 0)} resueltos · #{Map.get(@mascotas.por_estado, "posible_coincidencia", 0)} posibles coincidencias"}
        />
      </div>

      <div class="columnas">
        <.seccion titulo="Próximas necesidades por atender">
          <.vacio :if={@pendientes == []} texto="No hay necesidades pendientes." />
          <table :if={@pendientes != []} class="tabla">
            <thead>
              <tr><th>Id</th><th>Tipo</th><th>Prioridad</th><th>Zona</th><th>Avance</th></tr>
            </thead>
            <tbody>
              <tr :for={n <- @pendientes}>
                <td><strong>{n.id}</strong></td>
                <td>{n.tipo}</td>
                <td><.insignia texto={n.prioridad} /></td>
                <td>{n.zona}</td>
                <td><.barra valor={n.asignada} maximo={n.cantidad} /></td>
              </tr>
            </tbody>
          </table>
          <.link navigate={~p"/necesidades"} class="enlace">Ver todas las necesidades →</.link>
        </.seccion>

        <.seccion titulo="Ocupación de albergues">
          <.vacio :if={@lista_albergues == []} texto="No hay albergues registrados." />
          <div :for={a <- @lista_albergues} class="fila-barra">
            <span><strong>{a.codigo}</strong> {a.nombre}</span>
            <.barra valor={Albergue.ocupacion(a)} maximo={a.capacidad} />
          </div>
          <.link navigate={~p"/albergues"} class="enlace">Gestionar albergues →</.link>
        </.seccion>
      </div>

      <div class="columnas">
        <.seccion titulo={"Recursos críticos (≤ #{@umbral})"}>
          <.vacio :if={@criticos == []} texto="Ningún recurso está en nivel crítico." />
          <ul class="lista">
            <li :for={r <- @criticos}>
              <strong>{r.codigo}</strong> {r.nombre}: <span class="critico">{r.cantidad} {r.unidad}</span>
              <small>en {r.ubicacion}</small>
            </li>
          </ul>
        </.seccion>

        <.seccion titulo="Inventario disponible por categoría">
          <.vacio :if={@recursos.por_categoria == %{}} texto="No hay recursos registrados." />
          <ul class="lista">
            <li :for={{categoria, total} <- Enum.sort(@recursos.por_categoria)}>
              {categoria}: <strong>{total}</strong>
            </li>
          </ul>
        </.seccion>
      </div>

      <.seccion :if={puede?(@usuario, "simulate_conflict")} titulo="Demostración de concurrencia">
        <p class="nota">
          Lanza al mismo tiempo dos solicitudes (30 y 25 litros) sobre un recurso de 50 litros.
          El GenServer las atiende una por una: solo una se confirma y el inventario nunca queda
          negativo. Los datos de la simulación se eliminan al terminar.
        </p>
        <button type="button" class="boton boton-primario" phx-click="simular">
          Simular conflicto concurrente
        </button>
      </.seccion>

      <.resultado resultado={@resultado} />
    </Layouts.app>
    """
  end
end
